# OCI Provider Changes

This document outlines the key changes made to the GOADv3 project to support Oracle Cloud Infrastructure (OCI) deployment.

## Infrastructure Changes

### Terraform Configuration

#### Provider Configuration (main.tf)
```hcl
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
```

#### Network Configuration (network.tf)
- Added OCI Virtual Cloud Network (VCN) setup:
  ```hcl
  resource "oci_core_vcn" "goad_vcn" {
    compartment_id = var.compartment_ocid
    cidr_blocks    = ["192.168.56.0/24"]
    display_name   = "goad-vcn"
  }
  ```
- Configured subnets for both public and private networks
- Set up Internet Gateway and Route Tables
- Added Network Security Groups for Windows and Linux instances
- Configured security lists for AD-specific ports (53, 88, 389, 445, etc.)

#### Windows VM Configuration (windows.tf)
- Adapted Windows instance configuration for OCI:
  ```hcl
  resource "oci_core_instance" "windows_instance" {
    availability_domain = data.oci_identity_availability_domain.ad.name
    compartment_id      = var.compartment_ocid
    shape              = var.instance_shape
    source_details {
      source_id   = var.windows_image_ocid
      source_type = "image"
    }
    // ... other configuration
  }
  ```
- Added OCI-specific metadata for Windows configuration
- Configured boot volume with custom Windows image
- Set up network interfaces with proper security groups

#### SSH Configuration (ssh.tf)
- Added SSH key generation and management:
  ```hcl
  resource "tls_private_key" "ssh" {
    algorithm = "RSA"
    rsa_bits  = 4096
  }
  ```
- Configured key pairs for jumpbox access
- Set up secure key storage

#### Jumpbox Configuration (jumpbox.tf)
- Added Ubuntu jumpbox configuration:
  ```hcl
  resource "oci_core_instance" "jumpbox" {
    availability_domain = data.oci_identity_availability_domain.ad.name
    compartment_id      = var.compartment_ocid
    shape              = var.jumpbox_shape
    // ... other configuration
  }
  ```
- Configured public IP assignment
- Set up security groups for SSH access
- Added cloud-init scripts for initial setup

## Setup Script Changes

### scripts/setup_oci.sh

Changed from original GOADv3 ansible-core installation to use ansible[azure] for better Windows support:

```diff
- python3 -m pip install ansible-core==2.12.6
- python3 -m pip install pywinrm
+ # Create and activate virtual environment
+ mkdir -p /home/goad/.goad
+ $py -m venv /home/goad/.goad/.venv
+ source /home/goad/.goad/.venv/bin/activate
+
+ # Install ansible with Azure extras (includes Windows support) and pywinrm
+ pip install --upgrade pip
+ pip install 'ansible[azure]' pywinrm
```

Added Python version checks and requirements file selection:

```bash
# Check Python version
py=python3
version=$($py --version 2>&1 | awk '{print $2}')
echo "Python version in use : $version"
version_numeric=$(echo $version | awk -F. '{printf "%d%02d%02d\n", $1, $2, $3}')
if [ "$version_numeric" -lt 30800 ]; then
    echo "Python version is < 3.8 please update python before install"
    exit 1
fi

# Determine which requirements file to use based on Python version
if [ "$version_numeric" -lt 31100 ]; then
    requirement_file="requirements.yml"
else
    requirement_file="requirements_311.yml"
fi
```

## Ansible Changes

### ansible/data.yml

Updated interface detection to support both IPv4 address formats:

```diff
- when: item.ipv4.address == hostvars[dict_key].ansible_host
+ when: >
+   (item.ipv4[0].address is defined and item.ipv4[0].address == hostvars[dict_key].ansible_host) or
+   (item.ipv4.address is defined and item.ipv4.address == hostvars[dict_key].ansible_host)
```

This change makes the playbook more resilient by:
- Supporting both direct attribute (item.ipv4.address) and array format (item.ipv4[0].address)
- Adding existence checks to prevent attribute access errors
- Maintaining the same functionality while being more robust

## Virtual Environment Changes

Aligned virtual environment paths with goad.sh:
- Changed from `/home/goad/.venv` to `/home/goad/.goad/.venv`
- Updated all scripts and commands to use the correct path
- Ensures consistency across the project

## Windows Support Improvements

1. Ansible Installation:
   - Switched to ansible[azure] package which includes better Windows support
   - Added pywinrm for Windows remote management
   - Ensures Windows modules like win_psmodule are available

2. PowerShell Module Support:
   - Fixed issues with PowerShell module installation
   - Improved Windows host connectivity
   - Better handling of Windows-specific tasks

## OCI-Specific Features

1. Network Configuration:
   - VCN with proper CIDR blocks (192.168.56.0/24)
   - Security lists with AD-specific ports:
     - TCP: 53, 88, 135, 389, 445, 464, 636, 3268, 3269, 9389
     - UDP: 53, 88, 123, 389, 464
   - Network security groups for fine-grained control

2. Windows Integration:
   - OCI-specific Windows configuration
   - Custom Windows image handling
   - Proper network interface setup

3. Jumpbox Setup:
   - Ubuntu jumpbox with public IP
   - Secure SSH key management
   - Automated initial configuration

## Prerequisites

1. OCI Account Requirements:
   - Active OCI subscription
   - Proper IAM permissions
   - API keys configured

2. System Requirements:
   - Python >= 3.8
   - Terraform >= 0.12
   - OCI CLI configured

3. Required OCI Resources:
   - Compartment for GOAD resources
   - Windows Server image OCID
   - Ubuntu image for jumpbox
   - Proper quotas for compute and network resources

## Usage

1. Configure OCI credentials in terraform.tfvars:
   ```hcl
   tenancy_ocid     = "your-tenancy-ocid"
   user_ocid        = "your-user-ocid"
   fingerprint      = "your-key-fingerprint"
   private_key_path = "path-to-api-private-key"
   region           = "your-region"
   ```

2. Run setup script:
   ```bash
   ./scripts/setup_oci.sh
   ```

3. Deploy infrastructure:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Known Issues and Solutions

1. Windows Module Issues:
   - Use ansible[azure] package
   - Ensure pywinrm is installed
   - Check network security groups
   - Verify Windows firewall settings

2. Network Configuration:
   - Verify security list rules
   - Check route table configuration
   - Ensure proper subnet setup
   - Validate CIDR blocks

3. Authentication Issues:
   - Verify OCI API key configuration
   - Check SSH key permissions
   - Validate Windows credentials

These changes ensure better compatibility with OCI infrastructure while maintaining the core functionality of the GOADv3 project.
