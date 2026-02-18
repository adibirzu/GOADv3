#!/bin/bash
# =============================================================================
# GOADv3 Jumpbox Cloud-Init Script
# =============================================================================
# Clones the GOAD repo, installs Ansible + dependencies, writes a dynamic
# inventory, waits for all Windows hosts, then runs the full playbook sequence.
# All output is logged to /var/log/goad-provision.log.
#
# Variables injected via Terraform templatefile():
#   ansible_ssh_private_key, windows_password, goad_repo_url, goad_repo_branch,
#   windows_hosts (JSON map), enable_elk, elk_ip, enable_wazuh, wazuh_ip,
#   enable_management_agent, management_agent_install_key

set -euo pipefail
exec > >(tee -a /var/log/goad-provision.log) 2>&1
echo "=== GOADv3 provisioning started at $(date -u) ==="

GOAD_USER="goad"
GOAD_HOME="/home/$GOAD_USER"
GOAD_DIR="$GOAD_HOME/GOAD"
ANSIBLE_DIR="$GOAD_DIR/ansible"
VENV_DIR="$GOAD_HOME/.goad/.venv"

# --- Create goad user ---
if ! id "$GOAD_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$GOAD_USER"
  echo "$GOAD_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$GOAD_USER
fi

# --- Write Ansible SSH private key ---
mkdir -p "$GOAD_HOME/.ssh"
cat > "$GOAD_HOME/.ssh/ansible_key" <<'KEYEOF'
${ansible_ssh_private_key}
KEYEOF
chmod 600 "$GOAD_HOME/.ssh/ansible_key"
chown -R "$GOAD_USER:$GOAD_USER" "$GOAD_HOME/.ssh"

# --- Install system packages ---
echo "=== Installing system packages ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git python3-venv python3-pip netcat-openbsd jq

# --- Clone GOAD repository ---
echo "=== Cloning GOAD repository ==="
if [ ! -d "$GOAD_DIR" ]; then
  su - "$GOAD_USER" -c "git clone --branch '${goad_repo_branch}' '${goad_repo_url}' '$GOAD_DIR'"
fi

# --- Set up Python virtual environment ---
echo "=== Setting up Python venv ==="
mkdir -p "$GOAD_HOME/.goad"
su - "$GOAD_USER" -c "python3 -m venv '$VENV_DIR'"
su - "$GOAD_USER" -c "source '$VENV_DIR/bin/activate' && pip install --upgrade pip && pip install 'ansible[azure]' pywinrm"

# --- Determine requirements file based on Python version ---
PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor:02d}")')
if [ "$PY_VERSION" -lt "311" ]; then
  REQ_FILE="requirements.yml"
else
  REQ_FILE="requirements_311.yml"
fi

# --- Install Ansible Galaxy roles ---
echo "=== Installing Ansible Galaxy roles ==="
su - "$GOAD_USER" -c "source '$VENV_DIR/bin/activate' && cd '$ANSIBLE_DIR' && ansible-galaxy install -r '$REQ_FILE'"

# --- Write dynamic inventory ---
echo "=== Writing Ansible inventory ==="
cat > "$GOAD_DIR/ad/GOAD/providers/oci/inventory" <<'INVEOF'
[default]
; sevenkingdoms.local
%{ for key, host in windows_hosts ~}
${host.dict_key} ansible_host=${host.private_ip} dns_domain=${host.dns_domain} dict_key=${host.dict_key} ansible_user=ansible ansible_password=${windows_password}
%{ endfor ~}

%{ if enable_elk ~}
[elk]
elk ansible_host=${elk_ip} ansible_connection=ssh ansible_user=ubuntu ansible_ssh_private_key_file=$GOAD_HOME/.ssh/ansible_key

%{ endif ~}
%{ if enable_wazuh ~}
[wazuh]
wazuh ansible_host=${wazuh_ip} ansible_connection=ssh ansible_user=ubuntu ansible_ssh_private_key_file=$GOAD_HOME/.ssh/ansible_key

%{ endif ~}
[linux:vars]
ansible_user=ubuntu
ansible_connection=ssh
ansible_ssh_private_key_file=$GOAD_HOME/.ssh/ansible_key

[linux]
zeek ansible_host=192.168.56.25
arkime ansible_host=192.168.56.26

[all:vars]
domain_name=GOAD
force_dns_server=no
dns_server=9.9.9.9
two_adapters=no
domain_adapter=Ethernet 2

ansible_user=ansible
ansible_password=${windows_password}
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_operation_timeout_sec=400
ansible_winrm_read_timeout_sec=500
enable_http_proxy=no
INVEOF

chown "$GOAD_USER:$GOAD_USER" "$GOAD_DIR/ad/GOAD/providers/oci/inventory"

# --- Wait for WinRM on all Windows hosts ---
wait_for_winrm() {
  local host_ip="$1"
  local host_name="$2"
  local max_wait=1800  # 30 minutes
  local elapsed=0
  local interval=15

  echo "Waiting for WinRM on $host_name ($host_ip)..."
  while [ $elapsed -lt $max_wait ]; do
    if nc -z -w 3 "$host_ip" 5985 2>/dev/null; then
      echo "  $host_name ($host_ip) WinRM is ready after $${elapsed}s"
      return 0
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  echo "  WARNING: $host_name ($host_ip) WinRM not reachable after $${max_wait}s"
  return 1
}

echo "=== Waiting for Windows hosts ==="
%{ for key, host in windows_hosts ~}
wait_for_winrm "${host.private_ip}" "${host.dict_key}"
%{ endfor ~}

# Allow extra settling time after WinRM comes up
echo "Waiting 60s for Windows services to stabilize..."
sleep 60

# --- Run Ansible playbooks ---
run_playbook() {
  local playbook="$1"
  echo "=== Running playbook: $playbook at $(date -u) ==="
  su - "$GOAD_USER" -c "source '$VENV_DIR/bin/activate' && cd '$ANSIBLE_DIR' && ansible-playbook -i '$GOAD_DIR/ad/GOAD/providers/oci/inventory' '$playbook'"
  echo "=== Completed playbook: $playbook at $(date -u) ==="
}

echo "=== Starting GOAD playbook sequence at $(date -u) ==="

# Core AD playbook sequence (from playbooks.yml 'default' key)
PLAYBOOKS=(
  "build.yml"
  "ad-servers.yml"
  "ad-parent_domain.yml"
  "ad-child_domain.yml"
)

for pb in "$${PLAYBOOKS[@]}"; do
  run_playbook "$pb"
done

# Wait 5 minutes after child domain creation
echo "Waiting 5 minutes for child domain to stabilize..."
sleep 300

PLAYBOOKS_PHASE2=(
  "ad-members.yml"
  "ad-trusts.yml"
  "ad-data.yml"
  "ad-gmsa.yml"
  "laps.yml"
  "ad-relations.yml"
  "adcs.yml"
  "ad-acl.yml"
  "servers.yml"
  "security.yml"
  "vulnerabilities.yml"
)

for pb in "$${PLAYBOOKS_PHASE2[@]}"; do
  run_playbook "$pb"
done

echo "=== Core GOAD provisioning completed at $(date -u) ==="

# --- Extension playbooks ---
%{ if enable_elk ~}
echo "=== Running ELK playbooks ==="
run_playbook "elk.yml"
%{ endif ~}

%{ if enable_wazuh ~}
echo "=== Running Wazuh playbooks ==="
run_playbook "wazuh.yml"
%{ endif ~}

# --- Management Agent ---
%{ if enable_management_agent ~}
echo "=== Running Management Agent playbook ==="
export OCI_MGMT_AGENT_INSTALL_KEY="${management_agent_install_key}"
run_playbook "oci_management_agent.yml"
%{ endif ~}

echo "============================================="
echo "=== GOADv3 provisioning FINISHED at $(date -u) ==="
echo "============================================="
