variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_attachments" {
  description = "Map of VPC attachments to create"
  type = map(object({
    vpc_id           = string
    subnet_ids       = list(string)
    appliance_mode   = bool
    route_table_type = string # spoke, inspection, or onprem
  }))
  default = {}
}

variable "enable_inspection_routing" {
  description = "Enable inspection VPC routing for centralized security"
  type        = bool
  default     = true
}

variable "inspection_vpc_attachment_key" {
  description = "Key of the inspection VPC attachment for default routing"
  type        = string
  default     = ""
}

variable "enable_vpn" {
  description = "Enable Site-to-Site VPN connection"
  type        = bool
  default     = false
}

variable "customer_gateway_ip" {
  description = "IP address of the customer gateway (on-prem router)"
  type        = string
  default     = "1.2.3.4" # Placeholder - will be updated with actual on-prem router IP
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN for the customer gateway"
  type        = number
  default     = 65000
}

variable "vpn_enable_bgp" {
  description = "Enable BGP for VPN (dynamic routing)"
  type        = bool
  default     = false
}

variable "vpc_routes_to_tgw" {
  description = "Map of VPC routes to add pointing to Transit Gateway"
  type = map(object({
    route_table_id   = string
    destination_cidr = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
