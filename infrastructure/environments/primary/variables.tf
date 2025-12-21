################################################################################
# Project Configuration
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

################################################################################
# Region Configuration
################################################################################

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
# VPC Configuration
################################################################################

variable "vpc_configs" {
  description = "Configuration for each VPC"
  type = map(object({
    cidr_block  = string
    environment = string
  }))
  default = {
    prod = {
      cidr_block  = "10.1.0.0/16"
      environment = "production"
    }
    dev = {
      cidr_block  = "10.2.0.0/16"
      environment = "development"
    }
    shared = {
      cidr_block  = "10.3.0.0/16"
      environment = "shared-services"
    }
    onprem = {
      cidr_block  = "10.0.0.0/16"
      environment = "on-premises-simulation"
    }
  }
}

################################################################################
# Feature Flags
################################################################################

variable "enable_security_inspection" {
  description = "Enable GWLB + Suricata security inspection"
  type        = bool
  default     = true
}

variable "enable_storage_gateway" {
  description = "Enable Storage Gateway"
  type        = bool
  default     = true
}

variable "enable_datasync" {
  description = "Enable DataSync"
  type        = bool
  default     = true
}

variable "enable_transfer_family" {
  description = "Enable Transfer Family SFTP"
  type        = bool
  default     = true
}

variable "enable_vpn" {
  description = "Enable Site-to-Site VPN"
  type        = bool
  default     = false
}

################################################################################
# Application Configuration
################################################################################

variable "app_container_image" {
  description = "Container image for the application"
  type        = string
  default     = "nginx:alpine"
}

variable "app_container_port" {
  description = "Container port for the application"
  type        = number
  default     = 80
}

################################################################################
# Aurora Configuration
################################################################################

variable "aurora_min_capacity" {
  description = "Minimum ACU capacity for Aurora Serverless"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACU capacity for Aurora Serverless"
  type        = number
  default     = 4
}

################################################################################
# SFTP Configuration
################################################################################

variable "sftp_users" {
  description = "Map of SFTP users"
  type = map(object({
    public_key = string
  }))
  default = {}
}

################################################################################
# Tags
################################################################################

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
