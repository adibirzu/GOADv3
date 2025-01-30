# jumpbox.tf
resource "oci_core_instance" "jumpbox" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "jumpbox"
  
  shape = "VM.Standard.E4.Flex"
  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
    baseline_ocpu_utilization = "BASELINE_1_1"
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.public_subnet.id
    display_name             = "jumpbox-vnic"
    assign_public_ip         = true
    hostname_label           = "jumpbox"
    nsg_ids                  = []
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_image.images[0].id
    boot_volume_size_in_gbs = 100
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
  }

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
  }

  preserve_boot_volume = false
}
