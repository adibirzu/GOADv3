output "ubuntu_jumpbox_ip" {
  value = oci_core_instance.jumpbox.public_ip
}

output "windows_instance_details" {
  value = {
    for k, v in oci_core_instance.windows_instance : k => {
      hostname = v.display_name
      private_ip = v.private_ip
    }
  }
  description = "Windows instance details"
}

output "windows_password" {
  value     = var.windows_password
  sensitive = true
  description = "Password for Windows instances"
}