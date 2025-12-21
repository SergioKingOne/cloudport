################################################################################
# DR Environment Variables
################################################################################

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloudport"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "DR AWS region"
  type        = string
  default     = "us-west-2"
}

################################################################################
# Primary Environment References (from outputs)
################################################################################

variable "primary_alb_dns_name" {
  description = "DNS name of primary ALB"
  type        = string
  default     = ""
}

variable "primary_alb_zone_id" {
  description = "Zone ID of primary ALB"
  type        = string
  default     = ""
}

variable "primary_alb_arn" {
  description = "ARN of primary ALB"
  type        = string
  default     = ""
}

variable "global_cluster_id" {
  description = "Global cluster ID from primary Aurora"
  type        = string
  default     = ""
}

################################################################################
# DR Configuration
################################################################################

variable "enable_dr_app" {
  description = "Enable DR application deployment"
  type        = bool
  default     = true
}

variable "enable_global_accelerator" {
  description = "Enable Global Accelerator"
  type        = bool
  default     = true
}

variable "app_container_image" {
  description = "Container image for DR application"
  type        = string
  default     = "nginx:alpine"
}

variable "aurora_min_capacity" {
  description = "Minimum ACU for Aurora Serverless"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACU for Aurora Serverless"
  type        = number
  default     = 2
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
