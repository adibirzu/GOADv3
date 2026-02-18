# =============================================================================
# Windows AD Instances (5 hosts)
# =============================================================================

resource "oci_core_instance" "windows" {
  for_each = local.windows_instances

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = each.value.name
  shape               = var.windows_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.windows_ocpus
    memory_in_gbs = var.windows_memory_in_gbs
  }

  source_details {
    source_id               = each.value.image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = var.windows_boot_volume_size_in_gbs
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private.id
    hostname_label            = each.value.name
    private_ip                = each.value.private_ip
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
