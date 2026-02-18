# =============================================================================
# Outputs — Post-deployment information
# =============================================================================

output "jumpbox_public_ip" {
  description = "Public IP of the jumpbox instance."
  value       = oci_core_instance.jumpbox.public_ip
}

output "jumpbox_ssh_command" {
  description = "SSH command to connect to the jumpbox."
  value       = "ssh ubuntu@${oci_core_instance.jumpbox.public_ip}"
}

output "provision_log_command" {
  description = "Command to tail the provisioning log on the jumpbox."
  value       = "ssh ubuntu@${oci_core_instance.jumpbox.public_ip} 'tail -f /var/log/goad-provision.log'"
}

output "windows_instances" {
  description = "Map of Windows instance names to their private IPs."
  value = {
    for k, v in oci_core_instance.windows : k => v.private_ip
  }
}

output "windows_ansible_password" {
  description = "The password configured on all Windows instances for the 'ansible' user."
  value       = var.windows_password
  sensitive   = true
}

output "ansible_ssh_private_key" {
  description = "Generated SSH private key for Ansible (used by jumpbox to reach Linux targets)."
  value       = tls_private_key.ansible.private_key_pem
  sensitive   = true
}

# Extension outputs

output "elk_private_ip" {
  description = "Private IP of the ELK instance (if enabled)."
  value       = var.enable_elk ? oci_core_instance.elk[0].private_ip : null
}

output "wazuh_private_ip" {
  description = "Private IP of the Wazuh instance (if enabled)."
  value       = var.enable_wazuh ? oci_core_instance.wazuh[0].private_ip : null
}

output "workstation_private_ip" {
  description = "Private IP of the Windows workstation (if enabled)."
  value       = var.enable_workstation ? oci_core_instance.workstation[0].private_ip : null
}
