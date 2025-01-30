#!/bin/bash
set -e

# Create goad user
sudo useradd -m -s /bin/bash goad

# Create .ssh directory for goad user
sudo mkdir -p /home/goad/.ssh
sudo chmod 700 /home/goad/.ssh

# Copy the SSH key from ubuntu user to goad user
sudo cp /home/ubuntu/.ssh/authorized_keys /home/goad/.ssh/
sudo chown -R goad:goad /home/goad/.ssh
sudo chmod 600 /home/goad/.ssh/authorized_keys

# Add goad user to sudoers
echo "goad ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/goad

# Create GOAD directory structure
sudo mkdir -p /home/goad/GOAD
sudo chown -R goad:goad /home/goad/GOAD

# Install pip and required system packages for goad user
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv python3-dev gcc libkrb5-dev

# Create and activate virtual environment for goad user
sudo -u goad python3 -m venv /home/goad/.venv
sudo -u goad /home/goad/.venv/bin/pip install --upgrade pip

# Install ansible and required packages in the virtual environment
sudo -u goad /home/goad/.venv/bin/pip install ansible-core==2.12.6
sudo -u goad /home/goad/.venv/bin/pip install pywinrm[kerberos,credssp]
sudo -u goad /home/goad/.venv/bin/pip install requests-credssp
sudo -u goad /home/goad/.venv/bin/pip install requests-ntlm
sudo -u goad /home/goad/.venv/bin/pip install pypsrp[kerberos,credssp]

# Install required ansible collections using the ansible-galaxy from venv
sudo -u goad /home/goad/.venv/bin/ansible-galaxy collection install ansible.windows:==1.9.0
sudo -u goad /home/goad/.venv/bin/ansible-galaxy collection install community.general:==4.8.1
sudo -u goad /home/goad/.venv/bin/ansible-galaxy collection install community.windows:==1.9.0

# Add virtual environment activation to .bashrc
echo 'source /home/goad/.venv/bin/activate' | sudo -u goad tee -a /home/goad/.bashrc

# Create ansible.cfg in GOAD directory with WinRM settings
sudo -u goad tee /home/goad/GOAD/ansible.cfg << 'EOF'
[defaults]
interpreter_python = /home/goad/.venv/bin/python3
timeout = 60
host_key_checking = False

[persistent_connection]
command_timeout = 500

[winrm_connection]
scheme = https
transport = ntlm
server_cert_validation = ignore
conn_timeout = 500
message_encryption = auto
operation_timeout_sec = 500
read_timeout_sec = 500
EOF

# Create WinRM configuration directory
sudo -u goad mkdir -p /home/goad/.winrm/
sudo -u goad tee /home/goad/.winrm/config << 'EOF'
{
    "scheme": "https",
    "transport": "ntlm",
    "server_cert_validation": "ignore",
    "kerberos_delegation": true,
    "credssp_disable_tlsv1_2": false,
    "read_timeout_sec": 500,
    "operation_timeout_sec": 500,
    "message_encryption": "auto"
}
EOF
