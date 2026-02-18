resource "oci_core_instance" "jumpbox" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "jumpbox"
  shape               = var.shape

  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    memory_in_gbs             = var.memory_in_gbs
    ocpus                     = var.ocpus
  }

  source_details {
    source_id   = var.image_ocid
    source_type = "image"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = true
    subnet_id                 = oci_core_subnet.public_subnet.id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
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

  availability_config {
    is_live_migration_preferred = true
    recovery_action             = "RESTORE_INSTANCE"
  }

  platform_config {
    is_symmetric_multi_threading_enabled = true
    type                                 = "AMD_VM"
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
  }
}