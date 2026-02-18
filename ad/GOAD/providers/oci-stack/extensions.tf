# =============================================================================
# Optional Extensions — ELK, Wazuh, Workstation (count-gated)
# =============================================================================

# --- ELK Stack ---

resource "oci_core_instance" "elk" {
  count = var.enable_elk ? 1 : 0

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "elk"
  shape               = var.linux_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.elk_ocpus
    memory_in_gbs = var.elk_memory_in_gbs
  }

  source_details {
    source_id               = local.ubuntu_image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = var.linux_boot_volume_size_in_gbs
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private.id
    hostname_label            = "elk"
    private_ip                = var.elk_private_ip
  }

  metadata = {
    ssh_authorized_keys = local.combined_ssh_keys
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }
}

# --- Wazuh ---

resource "oci_core_instance" "wazuh" {
  count = var.enable_wazuh ? 1 : 0

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "wazuh"
  shape               = var.linux_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.wazuh_ocpus
    memory_in_gbs = var.wazuh_memory_in_gbs
  }

  source_details {
    source_id               = local.ubuntu_image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = var.linux_boot_volume_size_in_gbs
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private.id
    hostname_label            = "wazuh"
    private_ip                = var.wazuh_private_ip
  }

  metadata = {
    ssh_authorized_keys = local.combined_ssh_keys
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }
}

# --- Windows Workstation ---

resource "oci_core_instance" "workstation" {
  count = var.enable_workstation ? 1 : 0

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "workstation"
  shape               = var.windows_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.windows_ocpus
    memory_in_gbs = var.windows_memory_in_gbs
  }

  source_details {
    source_id               = local.windows2019_image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = var.windows_boot_volume_size_in_gbs
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private.id
    hostname_label            = "workstation"
    private_ip                = var.workstation_private_ip
  }

  metadata = {
    user_data = base64encode(templatefile("${path.module}/windows_cloud_init.ps1", {
      admin_username = "ansible"
      admin_password = var.windows_password
    }))
  }

  agent_config {
    is_management_disabled = false
    is_monitoring_disabled = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }
}
