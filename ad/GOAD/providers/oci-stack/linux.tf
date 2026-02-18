# =============================================================================
# Linux Instances — Arkime & Zeek
# =============================================================================

resource "oci_core_instance" "arkime" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "arkime"
  shape               = var.linux_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.linux_ocpus
    memory_in_gbs = var.linux_memory_in_gbs
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
    hostname_label            = "arkime"
    private_ip                = "192.168.56.26"
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

resource "oci_core_instance" "zeek" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "zeek"
  shape               = var.linux_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.linux_ocpus
    memory_in_gbs = var.linux_memory_in_gbs
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
    hostname_label            = "zeek"
    private_ip                = "192.168.56.25"
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
