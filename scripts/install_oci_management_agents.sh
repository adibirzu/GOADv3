#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLAYBOOK_NAME="oci_management_agent.yml"
PLAYBOOK_PATH="${PROJECT_ROOT}/ansible/${PLAYBOOK_NAME}"
OVERRIDE_FILE="${PROJECT_ROOT}/workspace/oci_management_agent_vars.yml"

INSTANCE_ID=""
INVENTORY_FILE=""
GLOBAL_INVENTORY_FILE="${PROJECT_ROOT}/globalsettings.ini"
WIN_ZIP_URL=""
WIN_RSP_URL=""
LINUX_ZIP_URL=""
LINUX_RSP_URL=""
INSTALL_KEY_ID=""
INSTALL_KEY_VALUE=""
WALLET_PASSWORD=""
SKIP_WINDOWS=false
SKIP_LINUX=false
PREPARE_ONLY=false
GENERATE_INSTALL_KEY=false
COMPARTMENT_ID=""
OCI_PROFILE=""

usage() {
  cat <<EOF
Usage:
  ${0##*/} [options]

Options:
  -i, --instance <instance_id>      GOAD instance id to target (optional if a default instance exists).
      --inventory <path>            Direct ansible inventory file (for already-provisioned projects).
      --global-inventory <path>     Extra inventory file (default: ${GLOBAL_INVENTORY_FILE}).
      --windows-zip-url <url>       OCI Management Agent Windows ZIP URL.
      --windows-rsp-url <url>       Windows response file URL.
      --linux-zip-url <url>         OCI Management Agent Linux package URL (ZIP or RPM).
      --linux-rsp-url <url>         Linux response file URL.
      --install-key-id <ocid>       OCI Management Agent install-key OCID (resolved via OCI CLI).
      --install-key-value <value>   Raw ManagementAgentInstallKey value (skip OCI CLI lookup).
      --generate-install-key        Auto-generate a new Management Agent install key via OCI CLI.
      --compartment-id <ocid>       Compartment OCID for install key generation (required with --generate-install-key).
      --oci-profile <name>          OCI CLI profile to use (optional, uses DEFAULT if not set).
      --wallet-password <password>  Optional CredentialWalletPassword for response file.
      --skip-windows                Skip Windows hosts.
      --skip-linux                  Skip Linux hosts.
      --prepare-only                Only write workspace override vars file, do not run goad.
  -h, --help                        Show this help.

Behavior:
  - Default mode uses existing GOAD deployment/provisioning mechanisms:
      python3 goad.py -t install -r ${PLAYBOOK_NAME} [-i <instance_id>]
  - If --inventory is set, runs ansible-playbook directly:
      ansible-playbook -i <inventory> [-i <global_inventory>] ${PLAYBOOK_PATH}
  - Installs on all hosts reachable in the selected instance inventory.
  - Overrides are written to:
      ${OVERRIDE_FILE}
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--instance)
      INSTANCE_ID="$2"
      shift 2
      ;;
    --windows-zip-url)
      WIN_ZIP_URL="$2"
      shift 2
      ;;
    --inventory)
      INVENTORY_FILE="$2"
      shift 2
      ;;
    --global-inventory)
      GLOBAL_INVENTORY_FILE="$2"
      shift 2
      ;;
    --windows-rsp-url)
      WIN_RSP_URL="$2"
      shift 2
      ;;
    --linux-zip-url)
      LINUX_ZIP_URL="$2"
      shift 2
      ;;
    --linux-rsp-url)
      LINUX_RSP_URL="$2"
      shift 2
      ;;
    --install-key-id)
      INSTALL_KEY_ID="$2"
      shift 2
      ;;
    --install-key-value)
      INSTALL_KEY_VALUE="$2"
      shift 2
      ;;
    --generate-install-key)
      GENERATE_INSTALL_KEY=true
      shift
      ;;
    --compartment-id)
      COMPARTMENT_ID="$2"
      shift 2
      ;;
    --oci-profile)
      OCI_PROFILE="$2"
      shift 2
      ;;
    --wallet-password)
      WALLET_PASSWORD="$2"
      shift 2
      ;;
    --skip-windows)
      SKIP_WINDOWS=true
      shift
      ;;
    --skip-linux)
      SKIP_LINUX=true
      shift
      ;;
    --prepare-only)
      PREPARE_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$SKIP_WINDOWS" == true && "$SKIP_LINUX" == true ]]; then
  echo "Both --skip-windows and --skip-linux are set; nothing to do." >&2
  exit 1
fi

if [[ -n "$INSTANCE_ID" && -n "$INVENTORY_FILE" ]]; then
  echo "Use either --instance or --inventory, not both." >&2
  exit 1
fi

mkdir -p "${PROJECT_ROOT}/workspace"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

generate_wallet_password() {
  local lower upper digit special tail
  lower="$(LC_ALL=C tr -dc 'a-z' </dev/urandom | head -c 1)"
  upper="$(LC_ALL=C tr -dc 'A-Z' </dev/urandom | head -c 1)"
  digit="$(LC_ALL=C tr -dc '0-9' </dev/urandom | head -c 1)"
  special="$(LC_ALL=C tr -dc '!@#%^&*' </dev/urandom | head -c 1)"
  tail="$(LC_ALL=C tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 12)"
  printf '%s' "${upper}${lower}${digit}${special}${tail}"
}

if [[ -n "$INSTALL_KEY_ID" && -n "$INSTALL_KEY_VALUE" ]]; then
  echo "Use either --install-key-id or --install-key-value, not both." >&2
  exit 1
fi

oci_cli() {
  if [[ -n "$OCI_PROFILE" ]]; then
    oci --profile "$OCI_PROFILE" "$@"
  else
    oci "$@"
  fi
}

if [[ "$GENERATE_INSTALL_KEY" == true ]]; then
  if ! command -v oci >/dev/null 2>&1; then
    echo "oci CLI not found in PATH; cannot generate install key." >&2
    exit 1
  fi

  if [[ -z "$COMPARTMENT_ID" ]]; then
    echo "--compartment-id is required when using --generate-install-key." >&2
    exit 1
  fi

  echo "Generating new Management Agent install key..."
  key_display_name="mgmt-agent-key-$(date +%Y%m%d-%H%M%S)"

  INSTALL_KEY_ID="$(oci_cli management-agent install-key create \
    --compartment-id "$COMPARTMENT_ID" \
    --display-name "$key_display_name" \
    --query 'data.id' --raw-output 2>&1)"

  if [[ -z "$INSTALL_KEY_ID" || "$INSTALL_KEY_ID" == *"Error"* || "$INSTALL_KEY_ID" == *"error"* ]]; then
    echo "Failed to create Management Agent install key: $INSTALL_KEY_ID" >&2
    exit 1
  fi
  echo "Created install key: $key_display_name ($INSTALL_KEY_ID)"
fi

if [[ -n "$INSTALL_KEY_ID" ]]; then
  if ! command -v oci >/dev/null 2>&1; then
    echo "oci CLI not found in PATH; cannot resolve --install-key-id." >&2
    exit 1
  fi
  key_content="$(oci_cli management-agent install-key get-install-key-content --file - --management-agent-install-key-id "$INSTALL_KEY_ID")"
  extracted_key="$(printf '%s\n' "$key_content" \
    | grep -iE '^[[:space:]]*ManagementAgentInstallKey[[:space:]]*=' \
    | head -n1 \
    | sed -E 's/^[[:space:]]*[Mm]anagement[Aa]gent[Ii]nstall[Kk]ey[[:space:]]*=[[:space:]]*//')"
  INSTALL_KEY_VALUE="$(trim "$extracted_key")"
  if [[ -z "$INSTALL_KEY_VALUE" ]]; then
    echo "Failed to parse ManagementAgentInstallKey from OCI install key content." >&2
    exit 1
  fi
fi

if [[ -n "$INSTALL_KEY_VALUE" && -z "$WALLET_PASSWORD" ]]; then
  WALLET_PASSWORD="$(generate_wallet_password)"
fi

if [[ -n "$WIN_ZIP_URL" || -n "$WIN_RSP_URL" || -n "$LINUX_ZIP_URL" || -n "$LINUX_RSP_URL" || -n "$INSTALL_KEY_VALUE" || -n "$WALLET_PASSWORD" || "$SKIP_WINDOWS" == true || "$SKIP_LINUX" == true || ! -f "$OVERRIDE_FILE" ]]; then
  cat > "$OVERRIDE_FILE" <<EOF
---
# Generated by scripts/install_oci_management_agents.sh
# Configure either:
# - install key mode (preferred): oci_mgmt_agent_install_key_value (+ optional wallet password)
# - response-file URL mode:      oci_mgmt_agent_*_rsp_url
oci_mgmt_agent_windows_zip_url: "${WIN_ZIP_URL:-https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/YOURPARFILE/b/Images/o/oracle.mgmt_agent.<VERSION>.Windows-x86_64.zip}"
oci_mgmt_agent_windows_rsp_url: "${WIN_RSP_URL:-}"
oci_mgmt_agent_linux_zip_url: "${LINUX_ZIP_URL:-https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/YOURPARFILE/b/Images/o/oracle.mgmt_agent.<VERSION>.Linux-x86_64.zip}"
oci_mgmt_agent_linux_rsp_url: "${LINUX_RSP_URL:-}"
oci_mgmt_agent_install_key_value: "${INSTALL_KEY_VALUE:-}"
oci_mgmt_agent_wallet_password: "${WALLET_PASSWORD:-}"
oci_mgmt_agent_skip_windows: ${SKIP_WINDOWS}
oci_mgmt_agent_skip_linux: ${SKIP_LINUX}
EOF
  echo "Wrote ${OVERRIDE_FILE}"
fi

if [[ "$PREPARE_ONLY" == true ]]; then
  echo "Prepare-only mode set, exiting without running goad."
  exit 0
fi

if [[ -n "$INVENTORY_FILE" ]]; then
  if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ansible-playbook not found in PATH." >&2
    exit 1
  fi

  if [[ -f "${PROJECT_ROOT}/ansible/ansible.cfg" ]]; then
    export ANSIBLE_CONFIG="${PROJECT_ROOT}/ansible/ansible.cfg"
  fi

  CMD=(ansible-playbook -i "$INVENTORY_FILE")
  if [[ -n "$GLOBAL_INVENTORY_FILE" && -f "$GLOBAL_INVENTORY_FILE" ]]; then
    CMD+=(-i "$GLOBAL_INVENTORY_FILE")
  fi
  CMD+=("$PLAYBOOK_PATH")
else
  CMD=(python3 "${PROJECT_ROOT}/goad.py" -t install -r "${PLAYBOOK_NAME}")
  if [[ -n "$INSTANCE_ID" ]]; then
    CMD+=(-i "$INSTANCE_ID")
  fi
fi

echo "Running: ${CMD[*]}"
"${CMD[@]}"
