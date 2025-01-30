data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E4.Flex"
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order              = "DESC"
}

data "oci_core_images" "windows_image" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Windows"
  operating_system_version = "Server 2019 Standard"
  shape                    = "VM.Standard.E4.Flex"
  state                    = "AVAILABLE"
  sort_by                  = "TIMECREATED"
  sort_order              = "DESC"
}