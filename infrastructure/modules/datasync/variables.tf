variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the DataSync agent"
  type        = string
}

variable "agent_subnet_id" {
  description = "Subnet ID for the DataSync agent"
  type        = string
}

variable "agent_instance_type" {
  description = "Instance type for the DataSync agent"
  type        = string
  default     = "m5.large"  # Minimum recommended for DataSync
}

variable "agent_ami_id" {
  description = "AMI ID for DataSync agent (defaults to latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "source_cidrs" {
  description = "CIDR blocks of source NFS servers"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "create_nfs_source" {
  description = "Whether to create NFS source location (set to false for testing)"
  type        = bool
  default     = true
}

variable "nfs_server_hostname" {
  description = "Hostname or IP of the NFS server"
  type        = string
  default     = ""
}

variable "nfs_subdirectory" {
  description = "Subdirectory on the NFS server"
  type        = string
  default     = "/"
}

variable "s3_subdirectory" {
  description = "Subdirectory in S3 bucket"
  type        = string
  default     = "/"
}

variable "bandwidth_limit_bytes_per_second" {
  description = "Bandwidth limit in bytes per second (-1 for no limit)"
  type        = number
  default     = 104857600 # 100 MB/s
}

variable "schedule_expression" {
  description = "Schedule expression for the DataSync task"
  type        = string
  default     = "cron(0 * * * ? *)" # Hourly
}

variable "log_retention_days" {
  description = "Number of days to retain DataSync logs"
  type        = number
  default     = 30
}

variable "create_vpc_endpoint" {
  description = "Whether to create a VPC endpoint for DataSync (enables private activation)"
  type        = bool
  default     = true
}

variable "vpc_endpoint_subnet_ids" {
  description = "Subnet IDs for the DataSync VPC endpoint (required if create_vpc_endpoint is true)"
  type        = list(string)
  default     = []
}

variable "private_link_endpoint" {
  description = "Existing VPC endpoint DNS name (used if create_vpc_endpoint is false)"
  type        = string
  default     = ""
}

variable "vpc_endpoint_id" {
  description = "Existing VPC endpoint ID (used if create_vpc_endpoint is false)"
  type        = string
  default     = ""
}

variable "subnet_arns" {
  description = "Existing subnet ARNs for DataSync agent (used if create_vpc_endpoint is false)"
  type        = list(string)
  default     = []
}

variable "security_group_arns" {
  description = "Existing security group ARNs for DataSync agent (used if create_vpc_endpoint is false)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
