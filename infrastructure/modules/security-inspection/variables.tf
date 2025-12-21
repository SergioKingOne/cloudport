variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security inspection infrastructure"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "gwlb_subnet_ids" {
  description = "Subnet IDs for the Gateway Load Balancer"
  type        = list(string)
}

variable "suricata_subnet_ids" {
  description = "Subnet IDs for Suricata instances"
  type        = list(string)
}

variable "gwlb_endpoints" {
  description = "Map of GWLB endpoints to create in spoke VPCs"
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
  default = {}
}

variable "instance_type" {
  description = "Instance type for Suricata instances"
  type        = string
  default     = "t3.small"  # Minimum for Suricata to run properly
}

variable "ami_id" {
  description = "AMI ID for Suricata instances (defaults to latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "desired_capacity" {
  description = "Desired number of Suricata instances"
  type        = number
  default     = 2  # Two instances for HA demo
}

variable "min_size" {
  description = "Minimum number of Suricata instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of Suricata instances"
  type        = number
  default     = 4
}

variable "suricata_rules_url" {
  description = "URL to download Suricata rules"
  type        = string
  default     = "https://rules.emergingthreats.net/open/suricata-5.0/emerging.rules.tar.gz"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH to Suricata instances"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Number of days to retain Suricata logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
