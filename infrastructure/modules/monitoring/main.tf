################################################################################
# Monitoring Module
# CloudWatch dashboards, CloudTrail, and centralized logging
################################################################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# CloudWatch Log Groups for Centralized Logging
################################################################################

resource "aws_cloudwatch_log_group" "central" {
  name              = "/aws/${var.name}/central"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

################################################################################
# CloudTrail
################################################################################

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "${var.name}-cloudtrail-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.name}-cloudtrail-bucket"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "archive-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "this" {
  name                          = "${var.name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = var.multi_region_trail
  enable_logging                = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  tags = var.tags

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

################################################################################
# SNS Topic for Alerts
################################################################################

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alerts"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

################################################################################
# CloudWatch Dashboard
################################################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      # Header
      [{
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# ${var.name} Infrastructure Dashboard"
        }
      }],

      # Transit Gateway Metrics
      var.transit_gateway_id != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 1
          width  = 12
          height = 6
          properties = {
            title  = "Transit Gateway - Bytes In/Out"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/TransitGateway", "BytesIn", "TransitGateway", var.transit_gateway_id],
              [".", "BytesOut", ".", "."]
            ]
            stat   = "Sum"
            period = 300
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 1
          width  = 12
          height = 6
          properties = {
            title  = "Transit Gateway - Packets"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/TransitGateway", "PacketsIn", "TransitGateway", var.transit_gateway_id],
              [".", "PacketsOut", ".", "."]
            ]
            stat   = "Sum"
            period = 300
          }
        }
      ] : [],

      # ECS Metrics
      var.ecs_cluster_name != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 7
          width  = 8
          height = 6
          properties = {
            title  = "ECS - CPU Utilization"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name]
            ]
            stat   = "Average"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 7
          width  = 8
          height = 6
          properties = {
            title  = "ECS - Memory Utilization"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name]
            ]
            stat   = "Average"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 7
          width  = 8
          height = 6
          properties = {
            title  = "ECS - Running Tasks"
            region = data.aws_region.current.name
            metrics = [
              ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name]
            ]
            stat   = "Average"
            period = 60
          }
        }
      ] : [],

      # Aurora Metrics
      var.aurora_cluster_id != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 13
          width  = 8
          height = 6
          properties = {
            title  = "Aurora - CPU Utilization"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_id]
            ]
            stat   = "Average"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 13
          width  = 8
          height = 6
          properties = {
            title  = "Aurora - Database Connections"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.aurora_cluster_id]
            ]
            stat   = "Sum"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 13
          width  = 8
          height = 6
          properties = {
            title  = "Aurora - Serverless Capacity"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/RDS", "ServerlessDatabaseCapacity", "DBClusterIdentifier", var.aurora_cluster_id]
            ]
            stat   = "Average"
            period = 60
          }
        }
      ] : [],

      # ALB Metrics
      var.alb_arn_suffix != "" ? [
        {
          type   = "metric"
          x      = 0
          y      = 19
          width  = 8
          height = 6
          properties = {
            title  = "ALB - Request Count"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
            ]
            stat   = "Sum"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 8
          y      = 19
          width  = 8
          height = 6
          properties = {
            title  = "ALB - Target Response Time"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
            ]
            stat   = "Average"
            period = 60
          }
        },
        {
          type   = "metric"
          x      = 16
          y      = 19
          width  = 8
          height = 6
          properties = {
            title  = "ALB - HTTP Error Codes"
            region = data.aws_region.current.name
            metrics = [
              ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", var.alb_arn_suffix],
              [".", "HTTPCode_Target_5XX_Count", ".", "."]
            ]
            stat   = "Sum"
            period = 60
          }
        }
      ] : []
    )
  })
}

################################################################################
# IAM Policy for Guardrails (SCP-like for single account)
################################################################################

resource "aws_iam_policy" "deny_unapproved_regions" {
  name        = "${var.name}-deny-unapproved-regions"
  description = "Deny actions in non-approved regions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnapprovedRegions"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.approved_regions
          }
          # Exclude global services
          "ForAnyValue:StringNotLike" = {
            "aws:PrincipalServiceName" = [
              "cloudfront.amazonaws.com",
              "iam.amazonaws.com",
              "route53.amazonaws.com",
              "globalaccelerator.amazonaws.com"
            ]
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "deny_cloudtrail_disable" {
  name        = "${var.name}-deny-cloudtrail-disable"
  description = "Deny disabling CloudTrail"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCloudTrailDisable"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "deny_public_s3" {
  name        = "${var.name}-deny-public-s3"
  description = "Deny creating public S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "s3:PublicAccessBlockConfiguration" = "false"
          }
        }
      }
    ]
  })

  tags = var.tags
}

################################################################################
# Config Rules for Compliance
################################################################################

resource "aws_config_configuration_recorder" "this" {
  count = var.enable_config ? 1 : 0

  name     = "${var.name}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported = true
  }
}

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
