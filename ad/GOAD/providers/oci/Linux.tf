resource "oci_core_instance" "arkime" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "Arkime"
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
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private_subnet.id
    private_ip                = "192.168.56.26"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  }
}

resource "oci_core_instance" "zeek" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "Zeek"
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
    assign_public_ip          = false
    subnet_id                 = oci_core_subnet.private_subnet.id
    private_ip                = "192.168.56.25"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_authorized_keys
  }
}