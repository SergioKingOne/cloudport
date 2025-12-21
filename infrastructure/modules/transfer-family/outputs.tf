output "server_id" {
  description = "ID of the Transfer Family server"
  value       = aws_transfer_server.sftp.id
}

output "server_arn" {
  description = "ARN of the Transfer Family server"
  value       = aws_transfer_server.sftp.arn
}

output "server_endpoint" {
  description = "Endpoint of the SFTP server"
  value       = aws_transfer_server.sftp.endpoint
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for SFTP uploads"
  value       = aws_s3_bucket.sftp.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for SFTP uploads"
  value       = aws_s3_bucket.sftp.arn
}

output "user_names" {
  description = "List of created SFTP user names"
  value       = [for u in aws_transfer_user.this : u.user_name]
}

output "sftp_connection_string" {
  description = "SFTP connection string template"
  value       = "sftp <username>@${aws_transfer_server.sftp.endpoint}"
}

output "custom_hostname" {
  description = "Custom hostname for SFTP (if configured)"
  value       = try(aws_route53_record.sftp[0].fqdn, null)
}

output "security_group_id" {
  description = "ID of the SFTP security group (if VPC endpoint)"
  value       = try(aws_security_group.sftp[0].id, null)
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.transfer.name
}
