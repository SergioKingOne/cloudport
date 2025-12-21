variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

variable "multi_region_trail" {
  description = "Enable multi-region CloudTrail"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

# Dashboard Metrics Sources
variable "transit_gateway_id" {
  description = "Transit Gateway ID for dashboard metrics"
  type        = string
  default     = ""
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for dashboard metrics"
  type        = string
  default     = ""
}

variable "aurora_cluster_id" {
  description = "Aurora cluster ID for dashboard metrics"
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for dashboard metrics"
  type        = string
  default     = ""
}

# Guardrails
variable "approved_regions" {
  description = "List of approved AWS regions"
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]
}

# AWS Config
variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
