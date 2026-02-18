# =============================================================================
# Computed Values
# =============================================================================

locals {
  # Resolve image OCIDs: use override if provided, otherwise use dynamic lookup
  ubuntu_image_ocid      = var.ubuntu_image_ocid != "" ? var.ubuntu_image_ocid : data.oci_core_images.ubuntu_22_04.images[0].id
  windows2019_image_ocid = var.windows2019_image_ocid != "" ? var.windows2019_image_ocid : data.oci_core_images.windows_2019.images[0].id
  windows2016_image_ocid = var.windows2016_image_ocid != "" ? var.windows2016_image_ocid : data.oci_core_images.windows_2016.images[0].id

  # Windows instance definitions — matches the existing GOAD topology
  windows_instances = {
    kingslanding = {
      name       = "kingslanding"
      private_ip = "192.168.56.10"
      image_ocid = local.windows2019_image_ocid
      dict_key   = "dc01"
      dns_domain = "dc01"
    }
    winterfell = {
      name       = "winterfell"
      private_ip = "192.168.56.11"
      image_ocid = local.windows2019_image_ocid
      dict_key   = "dc02"
      dns_domain = "dc01"
    }
    castelblack = {
      name       = "castelblack"
      private_ip = "192.168.56.22"
      image_ocid = local.windows2019_image_ocid
      dict_key   = "srv02"
      dns_domain = "dc02"
    }
    meereen = {
      name       = "meereen"
      private_ip = "192.168.56.12"
      image_ocid = local.windows2016_image_ocid
      dict_key   = "dc03"
      dns_domain = "dc03"
    }
    braavos = {
      name       = "braavos"
      private_ip = "192.168.56.23"
      image_ocid = local.windows2016_image_ocid
      dict_key   = "srv03"
      dns_domain = "dc03"
    }
  }

  # Combined SSH key: user's key + generated Ansible key
  ansible_ssh_public_key  = tls_private_key.ansible.public_key_openssh
  ansible_ssh_private_key = tls_private_key.ansible.private_key_pem
  combined_ssh_keys       = "${var.ssh_authorized_keys}\n${local.ansible_ssh_public_key}"

  # Playbook sequence (matches playbooks.yml 'default' key)
  playbook_sequence = [
    "build.yml",
    "ad-servers.yml",
    "ad-parent_domain.yml",
    "ad-child_domain.yml",
    "wait5m.yml",
    "ad-members.yml",
    "ad-trusts.yml",
    "ad-data.yml",
    "ad-gmsa.yml",
    "laps.yml",
    "ad-relations.yml",
    "adcs.yml",
    "ad-acl.yml",
    "servers.yml",
    "security.yml",
    "vulnerabilities.yml",
  ]
}
