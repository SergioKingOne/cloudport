output "cluster_id" {
  description = "ID of the Aurora cluster"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "cluster_identifier" {
  description = "Identifier of the Aurora cluster"
  value       = aws_rds_cluster.this.cluster_identifier
}

output "cluster_endpoint" {
  description = "Writer endpoint for the Aurora cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint for the Aurora cluster"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Port of the Aurora cluster"
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "Name of the default database"
  value       = aws_rds_cluster.this.database_name
}

output "master_username" {
  description = "Master username"
  value       = aws_rds_cluster.this.master_username
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.db.name
}

output "security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "instance_ids" {
  description = "IDs of the Aurora instances"
  value       = aws_rds_cluster_instance.this[*].id
}

output "instance_endpoints" {
  description = "Endpoints of the Aurora instances"
  value       = aws_rds_cluster_instance.this[*].endpoint
}

output "global_cluster_id" {
  description = "ID of the global cluster (if created)"
  value       = try(aws_rds_global_cluster.this[0].id, null)
}

output "connection_string" {
  description = "PostgreSQL connection string template"
  value       = "postgresql://${aws_rds_cluster.this.master_username}:<password>@${aws_rds_cluster.this.endpoint}:${aws_rds_cluster.this.port}/${aws_rds_cluster.this.database_name}"
  sensitive   = true
}
