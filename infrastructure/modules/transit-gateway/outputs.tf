output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "vpc_attachment_ids" {
  description = "Map of VPC attachment IDs"
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k => v.id }
}

output "spoke_route_table_id" {
  description = "ID of the spoke route table"
  value       = aws_ec2_transit_gateway_route_table.spoke.id
}

output "inspection_route_table_id" {
  description = "ID of the inspection route table"
  value       = try(aws_ec2_transit_gateway_route_table.inspection[0].id, null)
}

output "onprem_route_table_id" {
  description = "ID of the on-prem route table"
  value       = try(aws_ec2_transit_gateway_route_table.onprem[0].id, null)
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = try(aws_vpn_connection.this[0].id, null)
}

output "customer_gateway_id" {
  description = "ID of the customer gateway"
  value       = try(aws_customer_gateway.this[0].id, null)
}

output "vpn_tunnel1_address" {
  description = "Public IP of VPN tunnel 1"
  value       = try(aws_vpn_connection.this[0].tunnel1_address, null)
}

output "vpn_tunnel2_address" {
  description = "Public IP of VPN tunnel 2"
  value       = try(aws_vpn_connection.this[0].tunnel2_address, null)
}

output "vpn_tunnel1_preshared_key" {
  description = "Pre-shared key for VPN tunnel 1"
  value       = try(aws_vpn_connection.this[0].tunnel1_preshared_key, null)
  sensitive   = true
}

output "vpn_tunnel2_preshared_key" {
  description = "Pre-shared key for VPN tunnel 2"
  value       = try(aws_vpn_connection.this[0].tunnel2_preshared_key, null)
  sensitive   = true
}
