################################################################################
# DR Environment Outputs
################################################################################

output "dr_vpc_id" {
  description = "DR VPC ID"
  value       = module.vpc_dr.vpc_id
}

output "dr_app_url" {
  description = "DR Application URL"
  value       = var.enable_dr_app ? module.ecs_fargate_dr[0].app_url : null
}

output "dr_alb_dns_name" {
  description = "DR ALB DNS name"
  value       = var.enable_dr_app ? module.ecs_fargate_dr[0].alb_dns_name : null
}

output "dr_aurora_endpoint" {
  description = "DR Aurora cluster endpoint"
  value       = module.aurora_dr.cluster_endpoint
}

output "dr_aurora_reader_endpoint" {
  description = "DR Aurora reader endpoint"
  value       = module.aurora_dr.cluster_reader_endpoint
}

# Global Accelerator
output "global_accelerator_dns" {
  description = "Global Accelerator DNS name"
  value       = module.dr_routing.global_accelerator_dns_name
}

output "global_accelerator_ips" {
  description = "Global Accelerator static IP addresses"
  value       = module.dr_routing.global_accelerator_ip_addresses
}

# Health Checks
output "primary_health_check_id" {
  description = "Primary health check ID"
  value       = module.dr_routing.primary_health_check_id
}

output "secondary_health_check_id" {
  description = "Secondary health check ID"
  value       = module.dr_routing.secondary_health_check_id
}

# Access URLs
output "access_urls" {
  description = "All access URLs for the application"
  value = {
    primary_direct     = var.primary_alb_dns_name != "" ? "http://${var.primary_alb_dns_name}" : null
    dr_direct          = var.enable_dr_app ? module.ecs_fargate_dr[0].app_url : null
    global_accelerator = module.dr_routing.global_accelerator_dns_name != null ? "http://${module.dr_routing.global_accelerator_dns_name}" : null
  }
}
