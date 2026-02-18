# =============================================================================
# Jumpbox — Ubuntu instance that orchestrates Ansible provisioning
# =============================================================================

# Generate an SSH keypair for Ansible to connect to Linux targets
resource "tls_private_key" "ansible" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "oci_core_instance" "jumpbox" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "goad-jumpbox"
  shape               = var.linux_shape
  freeform_tags       = var.freeform_tags
  defined_tags        = var.defined_tags

  shape_config {
    ocpus         = var.jumpbox_ocpus
    memory_in_gbs = var.jumpbox_memory_in_gbs
  }

  source_details {
    source_id               = local.ubuntu_image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = var.linux_boot_volume_size_in_gbs
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = true
    assign_public_ip          = true
    subnet_id                 = oci_core_subnet.public.id
    hostname_label            = "jumpbox"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
    user_data = base64encode(templatefile("${path.module}/jumpbox_cloud_init.sh", {
      ansible_ssh_private_key      = local.ansible_ssh_private_key
      windows_password             = var.windows_password
      goad_repo_url                = var.goad_repo_url
      goad_repo_branch             = var.goad_repo_branch
      windows_hosts                = local.windows_instances
      enable_elk                   = var.enable_elk
      elk_ip                       = var.elk_private_ip
      enable_wazuh                 = var.enable_wazuh
      wazuh_ip                     = var.wazuh_private_ip
      enable_management_agent      = var.enable_management_agent
      management_agent_install_key = var.management_agent_install_key
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

  # Jumpbox must wait for all target instances to exist
  depends_on = [
    oci_core_instance.windows,
    oci_core_instance.arkime,
    oci_core_instance.zeek,
    oci_core_instance.elk,
    oci_core_instance.wazuh,
    oci_core_instance.workstation,
  ]
}
