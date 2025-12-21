output "gwlb_arn" {
  description = "ARN of the Gateway Load Balancer"
  value       = aws_lb.gwlb.arn
}

output "gwlb_id" {
  description = "ID of the Gateway Load Balancer"
  value       = aws_lb.gwlb.id
}

output "endpoint_service_name" {
  description = "Name of the VPC Endpoint Service"
  value       = aws_vpc_endpoint_service.gwlb.service_name
}

output "endpoint_service_id" {
  description = "ID of the VPC Endpoint Service"
  value       = aws_vpc_endpoint_service.gwlb.id
}

output "gwlb_endpoint_ids" {
  description = "Map of GWLB endpoint IDs in spoke VPCs"
  value       = { for k, v in aws_vpc_endpoint.gwlb : k => v.id }
}

output "target_group_arn" {
  description = "ARN of the Suricata target group"
  value       = aws_lb_target_group.suricata.arn
}

output "autoscaling_group_name" {
  description = "Name of the Suricata Auto Scaling Group"
  value       = aws_autoscaling_group.suricata.name
}

output "security_group_id" {
  description = "ID of the Suricata security group"
  value       = aws_security_group.suricata.id
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for Suricata"
  value       = aws_cloudwatch_log_group.suricata.name
}

output "iam_role_arn" {
  description = "ARN of the Suricata IAM role"
  value       = aws_iam_role.suricata.arn
}
