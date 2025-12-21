################################################################################
# Aurora PostgreSQL Module
# Aurora PostgreSQL Serverless v2 cluster with cross-region replication support
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# Random Password for Master User
################################################################################

resource "random_password" "master" {
  count = var.master_password == "" ? 1 : 0

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

################################################################################
# Secrets Manager for Database Credentials
################################################################################

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}-aurora-credentials"
  description = "Aurora PostgreSQL credentials for ${var.name}"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password != "" ? var.master_password : random_password.master[0].result
    engine   = "postgres"
    host     = aws_rds_cluster.this.endpoint
    port     = aws_rds_cluster.this.port
    dbname   = var.database_name
  })
}

################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  name        = "${var.name}-aurora-subnet-group"
  description = "Subnet group for Aurora PostgreSQL"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-aurora-subnet-group"
  })
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "aurora" {
  name        = "${var.name}-aurora-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "PostgreSQL from allowed security groups"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "PostgreSQL from allowed CIDRs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-aurora-sg"
  })
}

################################################################################
# Parameter Group
################################################################################

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name}-aurora-pg-params"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL parameter group"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = var.tags
}

################################################################################
# Global Cluster (for DR)
################################################################################

resource "aws_rds_global_cluster" "this" {
  count = var.create_global_cluster ? 1 : 0

  global_cluster_identifier = "${var.name}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.database_name
  storage_encrypted         = true
}

################################################################################
# Aurora Cluster
################################################################################

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name}-aurora-cluster"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = var.engine_version

  database_name   = var.is_secondary ? null : var.database_name
  master_username = var.is_secondary ? null : var.master_username
  master_password = var.is_secondary ? null : (var.master_password != "" ? var.master_password : random_password.master[0].result)

  global_cluster_identifier = var.global_cluster_identifier

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  backup_retention_period = var.backup_retention_days
  preferred_backup_window = "03:00-04:00"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot

  enabled_cloudwatch_logs_exports = ["postgresql"]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      master_password,
      global_cluster_identifier
    ]
  }
}

################################################################################
# Aurora Instances
################################################################################

resource "aws_rds_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.name}-aurora-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this.id

  instance_class = "db.serverless"
  engine         = aws_rds_cluster.this.engine
  engine_version = aws_rds_cluster.this.engine_version

  db_subnet_group_name = aws_db_subnet_group.this.name

  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.name}-aurora-instance-${count.index + 1}"
  })
}

################################################################################
# Enhanced Monitoring IAM Role
################################################################################

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name}-aurora-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.name}-aurora-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Aurora cluster CPU utilization is high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "${var.name}-aurora-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Aurora cluster connection count is high"

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.this.cluster_identifier
  }

  tags = var.tags
}
