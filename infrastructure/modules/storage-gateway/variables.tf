variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the Storage Gateway"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Storage Gateway instance"
  type        = string
}

variable "client_cidrs" {
  description = "CIDR blocks allowed to access the file share"
  type        = list(string)
}

variable "instance_type" {
  description = "Instance type for the Storage Gateway (m5.large is minimum supported)"
  type        = string
  default     = "m5.large"  # Minimum supported by Storage Gateway
}

variable "gateway_ami_id" {
  description = "AMI ID for Storage Gateway (defaults to latest AWS Storage Gateway AMI)"
  type        = string
  default     = ""
}

variable "cache_disk_size_gb" {
  description = "Size of the cache disk in GB"
  type        = number
  default     = 150
}

variable "glacier_ir_transition_days" {
  description = "Days before transitioning to Glacier Instant Retrieval"
  type        = number
  default     = 30
}

variable "deep_archive_transition_days" {
  description = "Days before transitioning to Deep Archive"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption (optional)"
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone for the Storage Gateway"
  type        = string
  default     = "GMT"
}

variable "use_public_ip" {
  description = "Whether to assign a public IP for gateway activation (required when running Terraform outside VPC)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
