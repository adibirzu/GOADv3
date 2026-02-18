# =============================================================================
# OCI Resource Manager Stack - Provider Configuration
# =============================================================================
# ORM auto-injects authentication. Only region is needed in the provider block.

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

provider "oci" {
  region = var.region
}
