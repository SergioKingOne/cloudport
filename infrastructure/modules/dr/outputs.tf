output "hosted_zone_id" {
  description = "ID of the Route 53 hosted zone"
  value       = try(aws_route53_zone.this[0].zone_id, var.hosted_zone_id)
}

output "hosted_zone_name_servers" {
  description = "Name servers of the hosted zone"
  value       = try(aws_route53_zone.this[0].name_servers, null)
}

output "primary_health_check_id" {
  description = "ID of the primary health check"
  value       = try(aws_route53_health_check.primary[0].id, null)
}

output "secondary_health_check_id" {
  description = "ID of the secondary health check"
  value       = try(aws_route53_health_check.secondary[0].id, null)
}

output "primary_record_fqdn" {
  description = "FQDN of the primary failover record"
  value       = try(aws_route53_record.primary[0].fqdn, null)
}

output "global_accelerator_id" {
  description = "ID of the Global Accelerator"
  value       = try(aws_globalaccelerator_accelerator.this[0].id, null)
}

output "global_accelerator_dns_name" {
  description = "DNS name of the Global Accelerator"
  value       = try(aws_globalaccelerator_accelerator.this[0].dns_name, null)
}

output "global_accelerator_ip_addresses" {
  description = "Static IP addresses of the Global Accelerator"
  value       = try(aws_globalaccelerator_accelerator.this[0].ip_sets[0].ip_addresses, null)
}

output "global_accelerator_listener_arn" {
  description = "ARN of the Global Accelerator listener"
  value       = try(aws_globalaccelerator_listener.this[0].id, null)
}

output "primary_endpoint_group_arn" {
  description = "ARN of the primary endpoint group"
  value       = try(aws_globalaccelerator_endpoint_group.primary[0].id, null)
}

output "secondary_endpoint_group_arn" {
  description = "ARN of the secondary endpoint group"
  value       = try(aws_globalaccelerator_endpoint_group.secondary[0].id, null)
}

output "app_url_route53" {
  description = "Application URL via Route 53 failover"
  value       = try("http://${aws_route53_record.primary[0].fqdn}", null)
}

output "app_url_global_accelerator" {
  description = "Application URL via Global Accelerator"
  value       = try("http://${aws_globalaccelerator_accelerator.this[0].dns_name}", null)
}
