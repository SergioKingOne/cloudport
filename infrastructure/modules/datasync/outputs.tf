output "agent_arn" {
  description = "ARN of the DataSync agent"
  value       = aws_datasync_agent.this.arn
}

output "agent_instance_id" {
  description = "EC2 instance ID of the DataSync agent"
  value       = aws_instance.datasync_agent.id
}

output "agent_private_ip" {
  description = "Private IP of the DataSync agent"
  value       = aws_instance.datasync_agent.private_ip
}

output "task_arn" {
  description = "ARN of the DataSync task"
  value       = try(aws_datasync_task.this[0].arn, null)
}

output "task_id" {
  description = "ID of the DataSync task"
  value       = try(aws_datasync_task.this[0].id, null)
}

output "s3_bucket_name" {
  description = "Name of the destination S3 bucket"
  value       = aws_s3_bucket.datasync.id
}

output "s3_bucket_arn" {
  description = "ARN of the destination S3 bucket"
  value       = aws_s3_bucket.datasync.arn
}

output "source_location_arn" {
  description = "ARN of the source NFS location"
  value       = try(aws_datasync_location_nfs.source[0].arn, null)
}

output "destination_location_arn" {
  description = "ARN of the destination S3 location"
  value       = aws_datasync_location_s3.destination.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for DataSync"
  value       = aws_cloudwatch_log_group.datasync.name
}

output "security_group_id" {
  description = "ID of the DataSync agent security group"
  value       = aws_security_group.datasync_agent.id
}

output "vpc_endpoint_id" {
  description = "ID of the DataSync VPC endpoint"
  value       = var.create_vpc_endpoint ? aws_vpc_endpoint.datasync[0].id : null
}

output "vpc_endpoint_dns" {
  description = "DNS name of the DataSync VPC endpoint"
  value       = var.create_vpc_endpoint ? aws_vpc_endpoint.datasync[0].dns_entry[0].dns_name : null
}
