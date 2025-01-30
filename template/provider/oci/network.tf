# Declare local values
locals {
  service_gateway_display_name = var.label_prefix == "none" ? var.service_gateway_display_name : "${var.label_prefix}-${var.service_gateway_display_name}"
}

#######################
# Virtual Cloud Network (VCN)
#######################

resource "oci_core_vcn" "generated_oci_core_vcn" {
  cidr_block     = "192.168.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "goad-virtual-network"
  dns_label      = "goadvcn"
}

#######################
# Subnets
#######################

resource "oci_core_subnet" "public_subnet" {
  cidr_block     = "192.168.57.0/24"
  compartment_id = var.compartment_ocid
  display_name   = "public-subnet"
  dns_label      = "publicsubnet"
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
  route_table_id = oci_core_route_table.public_route_table.id
}

resource "oci_core_subnet" "private_subnet" {
  cidr_block                 = "192.168.56.0/24"
  compartment_id             = var.compartment_ocid
  display_name               = "private-subnet"
  dns_label                  = "privatesubnet"
  vcn_id                     = oci_core_vcn.generated_oci_core_vcn.id
  route_table_id             = oci_core_route_table.private_route_table.id
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.winrm_rdp_security_list.id]
}

#######################
# Gateways
#######################

resource "oci_core_internet_gateway" "generated_oci_core_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "Internet Gateway goad-virtual-network"
  enabled        = true
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
}

resource "oci_core_nat_gateway" "generated_oci_core_nat_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "NAT Gateway goad-virtual-network"
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
}

#######################
# Service Gateway (SGW)
#######################

# Data block to fetch all OCI services
data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
  count = var.create_service_gateway == true ? 1 : 0
}

# Service Gateway Resource
resource "oci_core_service_gateway" "service_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = local.service_gateway_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  services {
    service_id = lookup(data.oci_core_services.all_oci_services[0].services[0], "id")
  }

  vcn_id = oci_core_vcn.generated_oci_core_vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_service_gateway == true ? 1 : 0
}

# Route Table for Service Gateway
resource "oci_core_route_table" "service_gw" {
  compartment_id = var.compartment_ocid
  display_name   = local.service_gateway_display_name

  freeform_tags = var.freeform_tags
  defined_tags  = var.defined_tags

  dynamic "route_rules" {
    for_each = var.create_service_gateway == true ? [1] : []

    content {
      destination       = lookup(data.oci_core_services.all_oci_services[0].services[0], "cidr_block")
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.service_gateway[0].id
      description       = "Terraformed - Auto-generated at Service Gateway creation: All Services in region to Service Gateway"
    }
  }

  vcn_id = oci_core_vcn.generated_oci_core_vcn.id

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }

  count = var.create_service_gateway == true ? 1 : 0
}

#######################
# Route Tables
#######################

resource "oci_core_route_table" "public_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
  display_name   = "public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.generated_oci_core_internet_gateway.id
  }
}

resource "oci_core_route_table" "private_route_table" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
  display_name   = "private-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.generated_oci_core_nat_gateway.id
  }
}

#######################
# DHCP Options
#######################

resource "oci_core_default_dhcp_options" "default_dhcp_options" {
  manage_default_resource_id = oci_core_vcn.generated_oci_core_vcn.default_dhcp_options_id

  options {
    type                  = "DomainNameServer"
    server_type           = "CustomDnsServer"
    custom_dns_servers    = ["192.168.56.10", "8.8.8.8"]
  }

  options {
    type                  = "SearchDomain"
    search_domain_names   = ["sevenkingdoms.local"]
  }
}

#######################
# Security List
#######################

resource "oci_core_security_list" "winrm_rdp_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.generated_oci_core_vcn.id
  display_name   = "winrm_rdp_security_list"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  ingress_security_rules {
    protocol    = "all"
    source      = "192.168.0.0/16"
    stateless   = false
  }
}