################################################################################
# Primary Environment Outputs
################################################################################

# VPC Outputs
output "vpc_ids" {
  description = "Map of VPC IDs"
  value = {
    prod   = module.vpc_prod.vpc_id
    dev    = module.vpc_dev.vpc_id
    shared = module.vpc_shared.vpc_id
    onprem = module.vpc_onprem.vpc_id
  }
}

# Transit Gateway
output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.transit_gateway.transit_gateway_id
}

# Application
output "app_url" {
  description = "Application URL"
  value       = module.ecs_fargate.app_url
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.ecs_fargate.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN (for DR configuration)"
  value       = module.ecs_fargate.alb_arn
}

output "alb_zone_id" {
  description = "ALB Zone ID (for Route 53)"
  value       = module.ecs_fargate.alb_zone_id
}

# Database
output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.aurora.cluster_endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = module.aurora.cluster_reader_endpoint
}

output "aurora_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = module.aurora.secret_arn
}

output "aurora_global_cluster_id" {
  description = "Global cluster ID for DR"
  value       = module.aurora.global_cluster_id
}

# Storage Gateway
output "storage_gateway_mount_command" {
  description = "Command to mount the NFS file share"
  value       = var.enable_storage_gateway ? module.storage_gateway[0].nfs_mount_command : null
}

output "storage_gateway_s3_bucket" {
  description = "S3 bucket for file gateway"
  value       = var.enable_storage_gateway ? module.storage_gateway[0].s3_bucket_name : null
}

# Transfer Family
output "sftp_endpoint" {
  description = "SFTP server endpoint"
  value       = var.enable_transfer_family ? module.transfer_family[0].server_endpoint : null
}

output "sftp_connection_string" {
  description = "SFTP connection string"
  value       = var.enable_transfer_family ? module.transfer_family[0].sftp_connection_string : null
}

# DataSync
output "datasync_s3_bucket" {
  description = "DataSync destination S3 bucket"
  value       = var.enable_datasync ? module.datasync[0].s3_bucket_name : null
}

# Monitoring
output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "cloudtrail_bucket" {
  description = "CloudTrail S3 bucket"
  value       = module.monitoring.cloudtrail_s3_bucket
}

# Security Inspection
output "gwlb_endpoint_service" {
  description = "GWLB endpoint service name"
  value       = var.enable_security_inspection ? module.security_inspection[0].endpoint_service_name : null
}
