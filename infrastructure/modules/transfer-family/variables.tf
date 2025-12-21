variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "endpoint_type" {
  description = "Endpoint type for the Transfer server (PUBLIC or VPC)"
  type        = string
  default     = "PUBLIC"
}

variable "vpc_id" {
  description = "VPC ID (required if endpoint_type is VPC)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC endpoint (required if endpoint_type is VPC)"
  type        = list(string)
  default     = []
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access SFTP (for VPC endpoint)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "security_policy" {
  description = "Security policy for the SFTP server"
  type        = string
  default     = "TransferSecurityPolicy-2024-01"
}

variable "users" {
  description = "Map of SFTP users to create"
  type = map(object({
    public_key = string
  }))
  default = {}
}

variable "custom_hostname" {
  description = "Custom hostname for the SFTP server"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for custom hostname"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain Transfer logs"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
