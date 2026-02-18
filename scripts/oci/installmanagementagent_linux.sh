#!/usr/bin/env bash
set -euo pipefail

MGMT_AGENT_PACKAGE_URL="${OCI_MGMT_AGENT_LINUX_PACKAGE_URL:-${OCI_MGMT_AGENT_LINUX_ZIP_URL:-}}"
RSP_URL="${OCI_MGMT_AGENT_LINUX_RSP_URL:-}"
INSTALL_KEY="${OCI_MGMT_AGENT_INSTALL_KEY:-}"
WALLET_PASSWORD="${OCI_MGMT_AGENT_WALLET_PASSWORD:-}"
RSP_LOCAL_PATH="/opt/oracle/mgmt_agent/agent.rsp"
WORK_ROOT="/tmp/oci-mgmt-agent-setup"

usage() {
  cat <<'EOF'
Usage:
  installmanagementagent_linux.sh \
    --management-agent-zip-url <url> \
    [--response-file-url <url>] \
    [--install-key <key>] \
    [--wallet-password <password>] \
    [--response-file-local-path <path>] \
    [--work-root <path>]

Note: --management-agent-zip-url accepts either ZIP or RPM package URLs.
EOF
}

log() {
  printf '[oci-mgmt-agent] %s\n' "$*"
}

fail() {
  printf '[oci-mgmt-agent] ERROR: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --management-agent-zip-url)
      MGMT_AGENT_PACKAGE_URL="$2"
      shift 2
      ;;
    --response-file-url)
      RSP_URL="$2"
      shift 2
      ;;
    --install-key)
      INSTALL_KEY="$2"
      shift 2
      ;;
    --wallet-password)
      WALLET_PASSWORD="$2"
      shift 2
      ;;
    --response-file-local-path)
      RSP_LOCAL_PATH="$2"
      shift 2
      ;;
    --work-root)
      WORK_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$MGMT_AGENT_PACKAGE_URL" ]] || fail "--management-agent-zip-url is required."
if [[ -z "$RSP_URL" && -z "$INSTALL_KEY" ]]; then
  fail "Provide either --response-file-url or --install-key."
fi

if [[ $EUID -ne 0 ]]; then
  fail "Run this script as root."
fi

install_pkg() {
  local pkg="$1"
  if command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    dnf install -y "$pkg"
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    yum install -y "$pkg"
    return
  fi
  if command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install "$pkg"
    return
  fi
  fail "No supported package manager found to install ${pkg}."
}

ensure_cmd() {
  local cmd="$1"
  local pkg="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Installing missing dependency: ${pkg}"
    install_pkg "$pkg"
  fi
}

is_rpm_url() {
  [[ "${MGMT_AGENT_PACKAGE_URL,,}" == *.rpm ]] || [[ "${MGMT_AGENT_PACKAGE_URL,,}" == *.rpm\?* ]]
}

java_major_version() {
  if ! command -v java >/dev/null 2>&1; then
    echo ""
    return
  fi
  local version_line
  version_line="$(java -version 2>&1 | head -n1)"
  if [[ "$version_line" =~ \"1\.([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$version_line" =~ \"([0-9]+)\.[0-9]+\.[0-9]+ ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$version_line" =~ \"([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return
  fi
  echo ""
}

ensure_java_runtime() {
  local major
  major="$(java_major_version)"
  if [[ -n "$major" && "$major" -ge 8 ]]; then
    log "Java runtime detected (major=${major})."
  else
    log "Java runtime not found (or too old), installing..."
    if command -v apt-get >/dev/null 2>&1; then
      install_pkg openjdk-11-jre-headless || install_pkg openjdk-8-jre-headless
    elif command -v dnf >/dev/null 2>&1; then
      install_pkg java-11-openjdk-headless || install_pkg java-1.8.0-openjdk-headless
    elif command -v yum >/dev/null 2>&1; then
      install_pkg java-11-openjdk-headless || install_pkg java-1.8.0-openjdk-headless
    elif command -v zypper >/dev/null 2>&1; then
      install_pkg java-11-openjdk-headless || install_pkg java-1_8_0-openjdk-headless
    else
      fail "No supported package manager found to install Java runtime."
    fi
  fi

  local java_bin java_home
  java_bin="$(command -v java || true)"
  [[ -n "$java_bin" ]] || fail "java command is still missing after install."
  java_home="$(dirname "$(dirname "$(readlink -f "$java_bin")")")"
  export JAVA_HOME="$java_home"
  export PATH="$JAVA_HOME/bin:$PATH"
  log "JAVA_HOME set to ${JAVA_HOME}"
}

service_installed() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files 2>/dev/null | grep -q '^mgmt_agent\.service'; then
      return 0
    fi
  fi
  return 1
}

if service_installed; then
  log "OCI Management Agent already installed, skipping."
  exit 0
fi

ensure_cmd curl curl
ensure_java_runtime

PKG_PATH="${WORK_ROOT}/agent_pkg"
ZIP_PATH="${WORK_ROOT}/agent.zip"
RPM_PATH="${WORK_ROOT}/agent.rpm"
EXTRACT_PATH="${WORK_ROOT}/extract"
RSP_DIR="$(dirname "$RSP_LOCAL_PATH")"

mkdir -p "$WORK_ROOT" "$EXTRACT_PATH" "$RSP_DIR"

if is_rpm_url; then
  PKG_PATH="$RPM_PATH"
  log "Downloading OCI Management Agent RPM..."
else
  PKG_PATH="$ZIP_PATH"
  ensure_cmd unzip unzip
  log "Downloading OCI Management Agent ZIP..."
fi
curl -fsSL "$MGMT_AGENT_PACKAGE_URL" -o "$PKG_PATH"

if [[ -n "$INSTALL_KEY" ]]; then
  log "Generating response file from install key..."
  {
    printf 'ManagementAgentInstallKey = %s\n' "$INSTALL_KEY"
    if [[ -n "$WALLET_PASSWORD" ]]; then
      printf 'CredentialWalletPassword = %s\n' "$WALLET_PASSWORD"
    fi
    printf 'Service.plugin.logan.download=true\n'
    printf 'Service.plugin.opsiHost.download=true\n'
    printf 'Service.plugin.appmgmt.download=true\n'
  } > "$RSP_LOCAL_PATH"
else
  log "Downloading response file..."
  curl -fsSL "$RSP_URL" -o "$RSP_LOCAL_PATH"
fi

if is_rpm_url; then
  ensure_cmd rpm rpm
  log "Installing OCI Management Agent RPM..."
  rpm -Uvh --replacepkgs "$RPM_PATH"
  SETUP_BIN="/opt/oracle/mgmt_agent/agent_inst/bin/setup.sh"
  [[ -x "$SETUP_BIN" ]] || fail "setup.sh not found after RPM installation."
  log "Running setup.sh with response file..."
  "$SETUP_BIN" "opts=$RSP_LOCAL_PATH"
else
  log "Extracting package..."
  unzip -oq "$ZIP_PATH" -d "$EXTRACT_PATH"

  find_installer() {
    find "$EXTRACT_PATH" -type f \( \
      -name "installer.sh" -o \
      -name "setup.sh" -o \
      -name "install*.sh" -o \
      -name "installer*.sh" \
    \) | head -n1
  }

  INSTALLER="$(find_installer)"
  [[ -n "$INSTALLER" ]] || fail "Installer not found in extracted package."

  chmod +x "$INSTALLER"
  log "Using installer: $INSTALLER"
  log "Running installer with response file as sole argument..."
  bash "$INSTALLER" "$RSP_LOCAL_PATH"
fi

if service_installed; then
  log "OCI Management Agent installation finished."
else
  log "Installer completed, but mgmt_agent service was not detected."
fi
