################################################################################
# Storage Gateway Module
# File Gateway for hybrid storage with S3 backend and lifecycle policies
################################################################################

data "aws_region" "current" {}

data "aws_ami" "storage_gateway" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["aws-storage-gateway-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# S3 Bucket for File Gateway
################################################################################

resource "aws_s3_bucket" "file_gateway" {
  bucket = "${var.name}-file-gateway-${data.aws_region.current.name}"

  tags = merge(var.tags, {
    Name = "${var.name}-file-gateway-bucket"
  })
}

resource "aws_s3_bucket_versioning" "file_gateway" {
  bucket = aws_s3_bucket.file_gateway.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "file_gateway" {
  bucket = aws_s3_bucket.file_gateway.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "file_gateway" {
  bucket = aws_s3_bucket.file_gateway.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# S3 Lifecycle Policies (Glacier Tiering)
################################################################################

resource "aws_s3_bucket_lifecycle_configuration" "file_gateway" {
  bucket = aws_s3_bucket.file_gateway.id

  rule {
    id     = "archive-to-glacier"
    status = "Enabled"

    transition {
      days          = var.glacier_ir_transition_days
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = var.deep_archive_transition_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

################################################################################
# Security Group for File Gateway
################################################################################

resource "aws_security_group" "file_gateway" {
  name        = "${var.name}-file-gateway-sg"
  description = "Security group for Storage Gateway"
  vpc_id      = var.vpc_id

  # NFS ports for file gateway
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = var.client_cidrs
    description = "NFS"
  }

  ingress {
    from_port   = 111
    to_port     = 111
    protocol    = "tcp"
    cidr_blocks = var.client_cidrs
    description = "Portmapper"
  }

  ingress {
    from_port   = 20048
    to_port     = 20048
    protocol    = "tcp"
    cidr_blocks = var.client_cidrs
    description = "NFS mountd"
  }

  # SMB ports (if needed)
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = var.client_cidrs
    description = "SMB"
  }

  # Gateway activation
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Gateway activation"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-file-gateway-sg"
  })
}

################################################################################
# IAM Role for File Gateway
################################################################################

resource "aws_iam_role" "file_gateway" {
  name = "${var.name}-file-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "storagegateway.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "file_gateway_s3" {
  name = "${var.name}-file-gateway-s3"
  role = aws_iam_role.file_gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetAccelerateConfiguration",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:ListBucketMultipartUploads"
        ]
        Effect   = "Allow"
        Resource = aws_s3_bucket.file_gateway.arn
      },
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:GetObjectVersion",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.file_gateway.arn}/*"
      }
    ]
  })
}

################################################################################
# EC2 Instance for File Gateway
################################################################################

resource "aws_iam_role" "gateway_ec2" {
  name = "${var.name}-gateway-ec2-role"

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

resource "aws_iam_role_policy_attachment" "gateway_ssm" {
  role       = aws_iam_role.gateway_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gateway" {
  name = "${var.name}-gateway-profile"
  role = aws_iam_role.gateway_ec2.name

  tags = var.tags
}

resource "aws_instance" "file_gateway" {
  ami           = var.gateway_ami_id != "" ? var.gateway_ami_id : data.aws_ami.storage_gateway.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.file_gateway.id]
  iam_instance_profile   = aws_iam_instance_profile.gateway.name

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
    Name = "${var.name}-file-gateway"
  })
}

# Cache disk for File Gateway
resource "aws_ebs_volume" "cache" {
  availability_zone = aws_instance.file_gateway.availability_zone
  size              = var.cache_disk_size_gb
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.name}-file-gateway-cache"
  })
}

resource "aws_volume_attachment" "cache" {
  device_name = "/dev/sdb"
  volume_id   = aws_ebs_volume.cache.id
  instance_id = aws_instance.file_gateway.id
}

################################################################################
# Storage Gateway Activation
# Note: Gateway activation requires manual steps or a separate process
################################################################################

resource "aws_storagegateway_gateway" "file_gateway" {
  gateway_ip_address = aws_instance.file_gateway.private_ip
  gateway_name       = "${var.name}-file-gateway"
  gateway_timezone   = var.timezone
  gateway_type       = "FILE_S3"

  tags = var.tags

  depends_on = [aws_volume_attachment.cache]
}

# Configure cache disk
resource "aws_storagegateway_cache" "file_gateway" {
  disk_id     = data.aws_storagegateway_local_disk.cache.disk_id
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
}

data "aws_storagegateway_local_disk" "cache" {
  disk_node   = "/dev/sdb"
  gateway_arn = aws_storagegateway_gateway.file_gateway.arn
}

################################################################################
# NFS File Share
################################################################################

resource "aws_storagegateway_nfs_file_share" "this" {
  client_list  = var.client_cidrs
  gateway_arn  = aws_storagegateway_gateway.file_gateway.arn
  location_arn = aws_s3_bucket.file_gateway.arn
  role_arn     = aws_iam_role.file_gateway.arn

  default_storage_class = "S3_STANDARD"
  guess_mime_type_enabled = true

  squash = "RootSquash"

  nfs_file_share_defaults {
    directory_mode = "0777"
    file_mode      = "0666"
    group_id       = 65534
    owner_id       = 65534
  }

  cache_attributes {
    cache_stale_timeout_in_seconds = 300
  }

  tags = var.tags
}
