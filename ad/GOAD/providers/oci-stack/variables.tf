# =============================================================================
# OCI Resource Manager Stack Variables for GOADv3
# =============================================================================
# Note: tenancy_ocid and compartment_ocid are auto-injected by ORM.
# No auth variables (user_ocid, fingerprint, private_key_path) needed.

# --- Identity & Region ---

variable "tenancy_ocid" {
  description = "The OCID of the tenancy (auto-injected by ORM)."
  type        = string
}

variable "compartment_ocid" {
  description = "The compartment where all resources will be created."
  type        = string
}

variable "region" {
  description = "The OCI region for deployment."
  type        = string
  default     = "eu-frankfurt-1"
}

variable "availability_domain" {
  description = "The availability domain for instance placement."
  type        = string
}

# --- SSH & Credentials ---

variable "ssh_authorized_keys" {
  description = "Your SSH public key for accessing the jumpbox."
  type        = string
}

variable "windows_password" {
  description = "Password for the 'ansible' user on all Windows instances. Must meet Windows complexity requirements."
  type        = string
  sensitive   = true
}

# --- Network ---

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (jumpbox)."
  type        = string
  default     = "192.168.57.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (AD hosts, Linux)."
  type        = string
  default     = "192.168.56.0/24"
}

variable "create_service_gateway" {
  description = "Create a Service Gateway for OCI service access without internet."
  type        = bool
  default     = true
}

# --- Windows Compute ---

variable "windows_shape" {
  description = "Compute shape for Windows AD instances."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "windows_ocpus" {
  description = "Number of OCPUs for each Windows instance."
  type        = number
  default     = 2
}

variable "windows_memory_in_gbs" {
  description = "Memory in GBs for each Windows instance."
  type        = number
  default     = 32
}

variable "windows_boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs for Windows instances."
  type        = number
  default     = 256
}

variable "windows2019_image_ocid" {
  description = "Override image OCID for Windows Server 2019. Leave empty for auto-lookup."
  type        = string
  default     = ""
}

variable "windows2016_image_ocid" {
  description = "Override image OCID for Windows Server 2016. Leave empty for auto-lookup."
  type        = string
  default     = ""
}

# --- Linux Compute ---

variable "linux_shape" {
  description = "Compute shape for Linux instances (Arkime, Zeek, jumpbox)."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "linux_ocpus" {
  description = "Number of OCPUs for each Linux instance."
  type        = number
  default     = 1
}

variable "linux_memory_in_gbs" {
  description = "Memory in GBs for each Linux instance."
  type        = number
  default     = 12
}

variable "linux_boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs for Linux instances."
  type        = number
  default     = 50
}

variable "ubuntu_image_ocid" {
  description = "Override image OCID for Ubuntu 22.04. Leave empty for auto-lookup."
  type        = string
  default     = ""
}

# --- Jumpbox ---

variable "jumpbox_ocpus" {
  description = "Number of OCPUs for the jumpbox (runs Ansible)."
  type        = number
  default     = 2
}

variable "jumpbox_memory_in_gbs" {
  description = "Memory in GBs for the jumpbox."
  type        = number
  default     = 16
}

variable "goad_repo_url" {
  description = "Git repository URL to clone for GOAD."
  type        = string
  default     = "https://github.com/adibirzu/GOADv3.git"
}

variable "goad_repo_branch" {
  description = "Git branch to checkout."
  type        = string
  default     = "main"
}

# --- Extensions ---

variable "enable_elk" {
  description = "Deploy an ELK stack instance."
  type        = bool
  default     = false
}

variable "elk_private_ip" {
  description = "Private IP for the ELK instance."
  type        = string
  default     = "192.168.56.50"
}

variable "elk_ocpus" {
  description = "Number of OCPUs for the ELK instance."
  type        = number
  default     = 2
}

variable "elk_memory_in_gbs" {
  description = "Memory in GBs for the ELK instance."
  type        = number
  default     = 16
}

variable "enable_wazuh" {
  description = "Deploy a Wazuh instance."
  type        = bool
  default     = false
}

variable "wazuh_private_ip" {
  description = "Private IP for the Wazuh instance."
  type        = string
  default     = "192.168.56.51"
}

variable "wazuh_ocpus" {
  description = "Number of OCPUs for the Wazuh instance."
  type        = number
  default     = 2
}

variable "wazuh_memory_in_gbs" {
  description = "Memory in GBs for the Wazuh instance."
  type        = number
  default     = 16
}

variable "enable_workstation" {
  description = "Deploy a Windows workstation instance."
  type        = bool
  default     = false
}

variable "workstation_private_ip" {
  description = "Private IP for the Windows workstation."
  type        = string
  default     = "192.168.56.31"
}

# --- Management Agent ---

variable "enable_management_agent" {
  description = "Run the OCI Management Agent install playbook after provisioning."
  type        = bool
  default     = false
}

variable "management_agent_install_key" {
  description = "OCI Management Agent install key (required if enable_management_agent is true)."
  type        = string
  default     = ""
  sensitive   = true
}

# --- Tags ---

variable "freeform_tags" {
  description = "Freeform tags applied to all resources."
  type        = map(string)
  default = {
    "Project" = "GOADv3"
  }
}

variable "defined_tags" {
  description = "Defined tags applied to all resources."
  type        = map(string)
  default     = {}
}
