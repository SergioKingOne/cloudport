################################################################################
# DataSync Module
# Automated data migration from on-premises to S3
################################################################################

data "aws_region" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# S3 Bucket for DataSync Destination
################################################################################

resource "aws_s3_bucket" "datasync" {
  bucket = "${var.name}-datasync-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.name}-datasync-bucket"
  })
}

resource "aws_s3_bucket_versioning" "datasync" {
  bucket = aws_s3_bucket.datasync.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datasync" {
  bucket = aws_s3_bucket.datasync.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "datasync" {
  bucket = aws_s3_bucket.datasync.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# DataSync Agent Security Group
################################################################################

resource "aws_security_group" "datasync_agent" {
  name        = "${var.name}-datasync-agent-sg"
  description = "Security group for DataSync agent"
  vpc_id      = var.vpc_id

  # NFS for source connection
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.source_cidrs
    description = "NFS to source"
  }

  # DataSync service
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DataSync service"
  }

  # Agent activation
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Agent activation"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-datasync-agent-sg"
  })
}

################################################################################
# IAM Role for DataSync Agent EC2
################################################################################

resource "aws_iam_role" "datasync_ec2" {
  name = "${var.name}-datasync-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "datasync_ssm" {
  role       = aws_iam_role.datasync_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "datasync" {
  name = "${var.name}-datasync-profile"
  role = aws_iam_role.datasync_ec2.name

  tags = var.tags
}

################################################################################
# DataSync Agent Instance
################################################################################

resource "aws_instance" "datasync_agent" {
  ami           = var.agent_ami_id != "" ? var.agent_ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.agent_instance_type
  subnet_id     = var.agent_subnet_id

  vpc_security_group_ids      = [aws_security_group.datasync_agent.id]
  iam_instance_profile        = aws_iam_instance_profile.datasync.name
  associate_public_ip_address = var.use_public_ip

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 80
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "${var.name}-datasync-agent"
  })
}

################################################################################
# DataSync Agent Activation
################################################################################

resource "aws_datasync_agent" "this" {
  ip_address = var.use_public_ip ? aws_instance.datasync_agent.public_ip : aws_instance.datasync_agent.private_ip
  name       = "${var.name}-datasync-agent"

  tags = var.tags
}

################################################################################
# IAM Role for DataSync S3 Location
################################################################################

resource "aws_iam_role" "datasync_s3" {
  name = "${var.name}-datasync-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "datasync.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "datasync_s3" {
  name = "${var.name}-datasync-s3-policy"
  role = aws_iam_role.datasync_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.datasync.arn
      },
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:GetObjectTagging",
          "s3:PutObjectTagging"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.datasync.arn}/*"
      }
    ]
  })
}

################################################################################
# DataSync Locations
################################################################################

# Source NFS Location (simulated on-prem)
resource "aws_datasync_location_nfs" "source" {
  count = var.create_nfs_source ? 1 : 0

  server_hostname = var.nfs_server_hostname
  subdirectory    = var.nfs_subdirectory

  on_prem_config {
    agent_arns = [aws_datasync_agent.this.arn]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-datasync-source"
  })
}

# Destination S3 Location
resource "aws_datasync_location_s3" "destination" {
  s3_bucket_arn = aws_s3_bucket.datasync.arn
  subdirectory  = var.s3_subdirectory

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name}-datasync-destination"
  })
}

################################################################################
# DataSync Task
################################################################################

resource "aws_datasync_task" "this" {
  count = var.create_nfs_source ? 1 : 0

  name                     = "${var.name}-datasync-task"
  source_location_arn      = aws_datasync_location_nfs.source[0].arn
  destination_location_arn = aws_datasync_location_s3.destination.arn

  options {
    bytes_per_second       = var.bandwidth_limit_bytes_per_second
    verify_mode            = "POINT_IN_TIME_CONSISTENT"
    preserve_deleted_files = "PRESERVE"
    posix_permissions      = "PRESERVE"
    uid                    = "INT_VALUE"
    gid                    = "INT_VALUE"
    log_level              = "TRANSFER"
  }

  schedule {
    schedule_expression = var.schedule_expression
  }

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync.arn

  tags = var.tags
}

################################################################################
# CloudWatch Log Group for DataSync
################################################################################

resource "aws_cloudwatch_log_group" "datasync" {
  name              = "/aws/datasync/${var.name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "datasync_errors" {
  alarm_name          = "${var.name}-datasync-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FilesSkipped"
  namespace           = "AWS/DataSync"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "DataSync task skipped files"

  dimensions = {
    TaskId = try(aws_datasync_task.this[0].id, "")
  }

  tags = var.tags
}
