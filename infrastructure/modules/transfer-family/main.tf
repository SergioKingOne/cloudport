################################################################################
# Transfer Family Module
# SFTP server for partner file uploads to S3
################################################################################

data "aws_region" "current" {}

################################################################################
# S3 Bucket for SFTP Uploads
################################################################################

resource "aws_s3_bucket" "sftp" {
  bucket = "${var.name}-sftp-uploads-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.name}-sftp-bucket"
  })
}

resource "aws_s3_bucket_versioning" "sftp" {
  bucket = aws_s3_bucket.sftp.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sftp" {
  bucket = aws_s3_bucket.sftp.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sftp" {
  bucket = aws_s3_bucket.sftp.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Security Group for SFTP Server
################################################################################

resource "aws_security_group" "sftp" {
  count = var.endpoint_type == "VPC" ? 1 : 0

  name        = "${var.name}-sftp-sg"
  description = "Security group for Transfer Family SFTP server"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "SFTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-sftp-sg"
  })
}

################################################################################
# IAM Role for Transfer Family Logging
################################################################################

resource "aws_iam_role" "transfer_logging" {
  name = "${var.name}-transfer-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "transfer_logging" {
  name = "${var.name}-transfer-logging-policy"
  role = aws_iam_role.transfer_logging.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:CreateLogGroup",
        "logs:PutLogEvents"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "transfer" {
  name              = "/aws/transfer/${var.name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

################################################################################
# Transfer Family Server
################################################################################

resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  domain                 = "S3"
  endpoint_type          = var.endpoint_type
  logging_role           = aws_iam_role.transfer_logging.arn

  # VPC endpoint configuration
  dynamic "endpoint_details" {
    for_each = var.endpoint_type == "VPC" ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.sftp[0].id]
      vpc_id             = var.vpc_id
    }
  }

  security_policy_name = var.security_policy

  tags = merge(var.tags, {
    Name = "${var.name}-sftp-server"
  })
}

################################################################################
# IAM Role for SFTP Users
################################################################################

resource "aws_iam_role" "sftp_user" {
  name = "${var.name}-sftp-user-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "transfer.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sftp_user" {
  name = "${var.name}-sftp-user-policy"
  role = aws_iam_role.sftp_user.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListingOfUserFolder"
        Action = ["s3:ListBucket"]
        Effect = "Allow"
        Resource = [aws_s3_bucket.sftp.arn]
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "$${transfer:UserName}/*",
              "$${transfer:UserName}"
            ]
          }
        }
      },
      {
        Sid    = "AllowReadWriteToUserFolder"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:GetObjectVersion"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.sftp.arn}/$${transfer:UserName}/*"
      }
    ]
  })
}

################################################################################
# SFTP Users
################################################################################

resource "aws_transfer_user" "this" {
  for_each = var.users

  server_id = aws_transfer_server.sftp.id
  user_name = each.key
  role      = aws_iam_role.sftp_user.arn

  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.sftp.id}/${each.key}"
  }

  tags = var.tags
}

resource "aws_transfer_ssh_key" "this" {
  for_each = { for k, v in var.users : k => v if v.public_key != "" }

  server_id = aws_transfer_server.sftp.id
  user_name = aws_transfer_user.this[each.key].user_name
  body      = each.value.public_key
}

################################################################################
# Route 53 Custom Hostname (Optional)
################################################################################

data "aws_route53_zone" "selected" {
  count = var.custom_hostname != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = var.hosted_zone_id
}

resource "aws_route53_record" "sftp" {
  count = var.custom_hostname != "" && var.hosted_zone_id != "" ? 1 : 0

  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.custom_hostname
  type    = "CNAME"
  ttl     = 300
  records = [aws_transfer_server.sftp.endpoint]
}
