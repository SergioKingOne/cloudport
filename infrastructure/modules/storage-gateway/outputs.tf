output "gateway_arn" {
  description = "ARN of the Storage Gateway"
  value       = aws_storagegateway_gateway.file_gateway.arn
}

output "gateway_id" {
  description = "ID of the Storage Gateway"
  value       = aws_storagegateway_gateway.file_gateway.id
}

output "gateway_instance_id" {
  description = "EC2 instance ID of the Storage Gateway"
  value       = aws_instance.file_gateway.id
}

output "gateway_private_ip" {
  description = "Private IP of the Storage Gateway"
  value       = aws_instance.file_gateway.private_ip
}

output "file_share_arn" {
  description = "ARN of the NFS file share"
  value       = aws_storagegateway_nfs_file_share.this.arn
}

output "file_share_path" {
  description = "Path to mount the NFS file share"
  value       = aws_storagegateway_nfs_file_share.this.path
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file storage"
  value       = aws_s3_bucket.file_gateway.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for file storage"
  value       = aws_s3_bucket.file_gateway.arn
}

output "security_group_id" {
  description = "ID of the Storage Gateway security group"
  value       = aws_security_group.file_gateway.id
}

output "nfs_mount_command" {
  description = "Command to mount the NFS file share"
  value       = "mount -t nfs -o nolock,hard ${aws_instance.file_gateway.private_ip}:${aws_storagegateway_nfs_file_share.this.path} /mnt/fileshare"
}

output "vpc_endpoint_id" {
  description = "ID of the Storage Gateway VPC endpoint"
  value       = var.create_vpc_endpoint ? aws_vpc_endpoint.storagegateway[0].id : null
}

output "vpc_endpoint_dns" {
  description = "DNS name of the Storage Gateway VPC endpoint"
  value       = var.create_vpc_endpoint ? aws_vpc_endpoint.storagegateway[0].dns_entry[0].dns_name : null
}
