variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the Aurora cluster"
  type        = list(string)
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "app"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Master password (generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 2  # Writer + reader for HA/read replica demo
}

variable "min_capacity" {
  description = "Minimum ACU capacity for Serverless v2"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum ACU capacity for Serverless v2"
  type        = number
  default     = 4
}

variable "allowed_security_groups" {
  description = "Security group IDs allowed to access Aurora"
  type        = list(string)
  default     = []
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access Aurora"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (uses AWS managed key if not provided)"
  type        = string
  default     = null
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)"
  type        = number
  default     = 60
}

variable "create_global_cluster" {
  description = "Create a global cluster for cross-region replication"
  type        = bool
  default     = false
}

variable "global_cluster_identifier" {
  description = "Global cluster identifier (for secondary clusters)"
  type        = string
  default     = null
}

variable "is_secondary" {
  description = "Whether this is a secondary cluster in a global database"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
