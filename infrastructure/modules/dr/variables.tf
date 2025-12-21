variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

# Route 53 Configuration
variable "create_hosted_zone" {
  description = "Create a new Route 53 hosted zone"
  type        = bool
  default     = false
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = ""
}

variable "record_name" {
  description = "DNS record name (e.g., app.example.com)"
  type        = string
  default     = ""
}

# Health Check Configuration
variable "create_health_checks" {
  description = "Create Route 53 health checks"
  type        = bool
  default     = true
}

variable "primary_endpoint" {
  description = "Primary endpoint FQDN for health check"
  type        = string
  default     = ""
}

variable "secondary_endpoint" {
  description = "Secondary endpoint FQDN for health check"
  type        = string
  default     = ""
}

variable "health_check_port" {
  description = "Port for health check"
  type        = number
  default     = 80
}

variable "health_check_type" {
  description = "Type of health check (HTTP, HTTPS, TCP)"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Path for HTTP/HTTPS health check"
  type        = string
  default     = "/"
}

variable "failure_threshold" {
  description = "Number of failures before unhealthy"
  type        = number
  default     = 3
}

variable "request_interval" {
  description = "Interval between health checks in seconds"
  type        = number
  default     = 30
}

# ALB Configuration
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
  description = "ARN of primary ALB (for Global Accelerator)"
  type        = string
  default     = ""
}

variable "secondary_alb_dns_name" {
  description = "DNS name of secondary ALB"
  type        = string
  default     = ""
}

variable "secondary_alb_zone_id" {
  description = "Zone ID of secondary ALB"
  type        = string
  default     = ""
}

variable "secondary_alb_arn" {
  description = "ARN of secondary ALB (for Global Accelerator)"
  type        = string
  default     = ""
}

# Global Accelerator Configuration
variable "create_global_accelerator" {
  description = "Create AWS Global Accelerator"
  type        = bool
  default     = true
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "primary_traffic_dial" {
  description = "Percentage of traffic to primary region (0-100)"
  type        = number
  default     = 100
}

variable "secondary_traffic_dial" {
  description = "Percentage of traffic to secondary region (0-100)"
  type        = number
  default     = 100
}

variable "enable_flow_logs" {
  description = "Enable Global Accelerator flow logs"
  type        = bool
  default     = false
}

variable "flow_logs_bucket" {
  description = "S3 bucket for flow logs"
  type        = string
  default     = ""
}

# Alerting
variable "alarm_actions" {
  description = "Actions to take when alarm triggers"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Actions to take when alarm resolves"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
