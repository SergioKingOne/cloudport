################################################################################
# Transit Gateway Module
# Creates a Transit Gateway hub with VPC attachments and optional VPN
################################################################################

################################################################################
# Transit Gateway
################################################################################

resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  vpn_ecmp_support                = "enable"
  dns_support                     = "enable"

  tags = merge(var.tags, {
    Name = "${var.name}-tgw"
  })
}

################################################################################
# VPC Attachments
################################################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  # Enable appliance mode for security inspection VPC
  appliance_mode_support = each.value.appliance_mode ? "enable" : "disable"
  dns_support            = "enable"

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-attachment-${each.key}"
  })
}

################################################################################
# Route Tables
################################################################################

# Spoke route table (for prod, dev VPCs)
resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-spoke"
  })
}

# Inspection route table (for shared-services VPC with security appliances)
resource "aws_ec2_transit_gateway_route_table" "inspection" {
  count = var.enable_inspection_routing ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-inspection"
  })
}

# On-prem route table (for VPN/Direct Connect)
resource "aws_ec2_transit_gateway_route_table" "onprem" {
  count = var.enable_vpn ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-rt-onprem"
  })
}

################################################################################
# Route Table Associations
################################################################################

resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  for_each = { for k, v in var.vpc_attachments : k => v if v.route_table_type == "spoke" }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  for_each = { for k, v in var.vpc_attachments : k => v if v.route_table_type == "inspection" && var.enable_inspection_routing }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection[0].id
}

resource "aws_ec2_transit_gateway_route_table_association" "onprem" {
  for_each = { for k, v in var.vpc_attachments : k => v if v.route_table_type == "onprem" && var.enable_vpn }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem[0].id
}

################################################################################
# Route Table Propagations
################################################################################

# Spoke VPCs propagate to inspection route table
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke_to_inspection" {
  for_each = { for k, v in var.vpc_attachments : k => v if v.route_table_type == "spoke" && var.enable_inspection_routing }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection[0].id
}

# Inspection VPC propagates to spoke route table
resource "aws_ec2_transit_gateway_route_table_propagation" "inspection_to_spoke" {
  for_each = { for k, v in var.vpc_attachments : k => v if v.route_table_type == "inspection" && var.enable_inspection_routing }

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

# All VPCs propagate to onprem route table
resource "aws_ec2_transit_gateway_route_table_propagation" "all_to_onprem" {
  for_each = var.enable_vpn ? var.vpc_attachments : {}

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem[0].id
}

################################################################################
# Static Routes
################################################################################

# Default route from spoke to inspection VPC (for security inspection)
resource "aws_ec2_transit_gateway_route" "spoke_default_to_inspection" {
  count = var.enable_inspection_routing && var.inspection_vpc_attachment_key != "" ? 1 : 0

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[var.inspection_vpc_attachment_key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

################################################################################
# Site-to-Site VPN (Simulated On-Prem Connection)
################################################################################

resource "aws_customer_gateway" "this" {
  count = var.enable_vpn ? 1 : 0

  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = merge(var.tags, {
    Name = "${var.name}-cgw"
  })
}

resource "aws_vpn_connection" "this" {
  count = var.enable_vpn ? 1 : 0

  customer_gateway_id = aws_customer_gateway.this[0].id
  transit_gateway_id  = aws_ec2_transit_gateway.this.id
  type                = "ipsec.1"
  static_routes_only  = !var.vpn_enable_bgp

  tags = merge(var.tags, {
    Name = "${var.name}-vpn"
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "vpn" {
  count = var.enable_vpn ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.this[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.onprem[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "vpn_to_spoke" {
  count = var.enable_vpn ? 1 : 0

  transit_gateway_attachment_id  = aws_vpn_connection.this[0].transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spoke.id
}

################################################################################
# VPC Route Table Updates (routes to TGW)
################################################################################

resource "aws_route" "vpc_to_tgw" {
  for_each = var.vpc_routes_to_tgw

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
