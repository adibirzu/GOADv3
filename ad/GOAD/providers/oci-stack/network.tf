# =============================================================================
# Network — VCN, Subnets, Gateways, Security Lists, DHCP
# =============================================================================

#######################
# Virtual Cloud Network
#######################

resource "oci_core_vcn" "goad" {
  cidr_block     = var.vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "goad-virtual-network"
  dns_label      = "goadvcn"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags
}

#######################
# Internet Gateway
#######################

resource "oci_core_internet_gateway" "goad" {
  compartment_id = var.compartment_ocid
  display_name   = "goad-internet-gateway"
  enabled        = true
  vcn_id         = oci_core_vcn.goad.id
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags
}

#######################
# NAT Gateway
#######################

resource "oci_core_nat_gateway" "goad" {
  compartment_id = var.compartment_ocid
  display_name   = "goad-nat-gateway"
  vcn_id         = oci_core_vcn.goad.id
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags
}

#######################
# Service Gateway
#######################

resource "oci_core_service_gateway" "goad" {
  count = var.create_service_gateway ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "goad-service-gateway"
  vcn_id         = oci_core_vcn.goad.id
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  services {
    service_id = data.oci_core_services.all_oci_services[0].services[0].id
  }

  lifecycle {
    ignore_changes = [defined_tags, freeform_tags]
  }
}

#######################
# Route Tables
#######################

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.goad.id
  display_name   = "goad-public-route-table"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.goad.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.goad.id
  display_name   = "goad-private-route-table"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.goad.id
  }

  dynamic "route_rules" {
    for_each = var.create_service_gateway ? [1] : []
    content {
      destination       = data.oci_core_services.all_oci_services[0].services[0].cidr_block
      destination_type  = "SERVICE_CIDR_BLOCK"
      network_entity_id = oci_core_service_gateway.goad[0].id
    }
  }
}

#######################
# Security Lists
#######################

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.goad.id
  display_name   = "goad-private-security-list"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  # Allow all egress
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # Allow all traffic within VCN
  ingress_security_rules {
    protocol  = "all"
    source    = var.vcn_cidr
    stateless = false
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.goad.id
  display_name   = "goad-public-security-list"
  freeform_tags  = var.freeform_tags
  defined_tags   = var.defined_tags

  # Allow all egress
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }

  # SSH from anywhere
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow all traffic within VCN
  ingress_security_rules {
    protocol  = "all"
    source    = var.vcn_cidr
    stateless = false
  }
}

#######################
# Subnets
#######################

resource "oci_core_subnet" "public" {
  cidr_block        = var.public_subnet_cidr
  compartment_id    = var.compartment_ocid
  display_name      = "goad-public-subnet"
  dns_label         = "goadpublic"
  vcn_id            = oci_core_vcn.goad.id
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]
  freeform_tags     = var.freeform_tags
  defined_tags      = var.defined_tags
}

resource "oci_core_subnet" "private" {
  cidr_block                 = var.private_subnet_cidr
  compartment_id             = var.compartment_ocid
  display_name               = "goad-private-subnet"
  dns_label                  = "goadprivate"
  vcn_id                     = oci_core_vcn.goad.id
  route_table_id             = oci_core_route_table.private.id
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.private.id]
  freeform_tags              = var.freeform_tags
  defined_tags               = var.defined_tags
}

#######################
# DHCP Options
#######################

resource "oci_core_default_dhcp_options" "goad" {
  manage_default_resource_id = oci_core_vcn.goad.default_dhcp_options_id

  options {
    type               = "DomainNameServer"
    server_type        = "CustomDnsServer"
    custom_dns_servers = ["192.168.56.10", "8.8.8.8"]
  }

  options {
    type                = "SearchDomain"
    search_domain_names = ["sevenkingdoms.local"]
  }
}
