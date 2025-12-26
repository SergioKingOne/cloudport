################################################################################
# Primary Environment - Main Configuration
# Enterprise AWS Migration Infrastructure
################################################################################

locals {
  name = "${var.project_name}-${var.environment}"
  tags = merge(var.common_tags, {
    Project     = var.project_name
    Environment = var.environment
  })
}

################################################################################
# VPCs - Simulated Multi-Account Structure
################################################################################

module "vpc_prod" {
  source = "../../modules/vpc"

  name               = "${local.name}-prod"
  cidr_block         = var.vpc_configs.prod.cidr_block
  az_count           = 2
  create_nat_gateway = true
  single_nat_gateway = true # Cost optimization for demo
  enable_flow_logs   = true

  tags = merge(local.tags, {
    VPC         = "production"
    Environment = "production"
  })
}

module "vpc_dev" {
  source = "../../modules/vpc"

  name               = "${local.name}-dev"
  cidr_block         = var.vpc_configs.dev.cidr_block
  az_count           = 2
  create_nat_gateway = true
  single_nat_gateway = true
  enable_flow_logs   = true

  tags = merge(local.tags, {
    VPC         = "development"
    Environment = "development"
  })
}

module "vpc_shared" {
  source = "../../modules/vpc"

  name               = "${local.name}-shared"
  cidr_block         = var.vpc_configs.shared.cidr_block
  az_count           = 2
  create_nat_gateway = true
  single_nat_gateway = true
  enable_flow_logs   = true

  tags = merge(local.tags, {
    VPC         = "shared-services"
    Environment = "shared"
  })
}

module "vpc_onprem" {
  source = "../../modules/vpc"

  name               = "${local.name}-onprem"
  cidr_block         = var.vpc_configs.onprem.cidr_block
  az_count           = 2
  create_nat_gateway = true
  single_nat_gateway = true
  enable_flow_logs   = true

  tags = merge(local.tags, {
    VPC         = "on-premises-simulation"
    Environment = "onprem"
  })
}

################################################################################
# Transit Gateway - Network Hub
################################################################################

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name = local.name

  vpc_attachments = {
    prod = {
      vpc_id           = module.vpc_prod.vpc_id
      subnet_ids       = module.vpc_prod.private_subnet_ids
      appliance_mode   = false
      route_table_type = "spoke"
    }
    dev = {
      vpc_id           = module.vpc_dev.vpc_id
      subnet_ids       = module.vpc_dev.private_subnet_ids
      appliance_mode   = false
      route_table_type = "spoke"
    }
    shared = {
      vpc_id           = module.vpc_shared.vpc_id
      subnet_ids       = module.vpc_shared.private_subnet_ids
      appliance_mode   = true # Enable for security inspection
      route_table_type = "inspection"
    }
    onprem = {
      vpc_id           = module.vpc_onprem.vpc_id
      subnet_ids       = module.vpc_onprem.private_subnet_ids
      appliance_mode   = false
      route_table_type = "onprem"
    }
  }

  enable_inspection_routing     = var.enable_security_inspection
  inspection_vpc_attachment_key = "shared"

  enable_vpn = var.enable_vpn

  # Add routes from spoke VPCs to other VPCs via TGW
  vpc_routes_to_tgw = merge(
    { for idx, rt_id in module.vpc_prod.private_route_table_ids : "prod-to-tgw-${idx}" => {
      route_table_id   = rt_id
      destination_cidr = "10.0.0.0/8"
    } },
    { for idx, rt_id in module.vpc_dev.private_route_table_ids : "dev-to-tgw-${idx}" => {
      route_table_id   = rt_id
      destination_cidr = "10.0.0.0/8"
    } },
    { for idx, rt_id in module.vpc_shared.private_route_table_ids : "shared-to-tgw-${idx}" => {
      route_table_id   = rt_id
      destination_cidr = "10.0.0.0/8"
    } },
    { for idx, rt_id in module.vpc_onprem.private_route_table_ids : "onprem-to-tgw-${idx}" => {
      route_table_id   = rt_id
      destination_cidr = "10.0.0.0/8"
    } }
  )

  tags = local.tags
}

################################################################################
# Security Inspection - GWLB + Suricata
################################################################################

module "security_inspection" {
  source = "../../modules/security-inspection"
  count  = var.enable_security_inspection ? 1 : 0

  name = local.name

  vpc_id   = module.vpc_shared.vpc_id
  vpc_cidr = module.vpc_shared.vpc_cidr_block

  gwlb_subnet_ids     = module.vpc_shared.private_subnet_ids
  suricata_subnet_ids = module.vpc_shared.private_subnet_ids

  # Create GWLB endpoints in spoke VPCs (one subnet per endpoint required)
  gwlb_endpoints = {
    prod = {
      vpc_id     = module.vpc_prod.vpc_id
      subnet_ids = [module.vpc_prod.private_subnet_ids[0]]
    }
    dev = {
      vpc_id     = module.vpc_dev.vpc_id
      subnet_ids = [module.vpc_dev.private_subnet_ids[0]]
    }
  }

  instance_type    = "t3.small"  # Minimum for Suricata
  desired_capacity = 2           # HA demo
  min_size         = 1
  max_size         = 4

  tags = local.tags
}

################################################################################
# Storage Gateway - Hybrid File Storage
################################################################################

module "storage_gateway" {
  source = "../../modules/storage-gateway"
  count  = var.enable_storage_gateway ? 1 : 0

  name = local.name

  vpc_id    = module.vpc_onprem.vpc_id
  subnet_id = module.vpc_onprem.private_subnet_ids[0]

  client_cidrs = [
    module.vpc_onprem.vpc_cidr_block,
    module.vpc_prod.vpc_cidr_block,
    module.vpc_dev.vpc_cidr_block
  ]

  # VPC endpoint for private activation (no public IP needed)
  create_vpc_endpoint     = true
  vpc_endpoint_subnet_ids = module.vpc_onprem.private_subnet_ids

  glacier_ir_transition_days   = 30
  deep_archive_transition_days = 180

  tags = local.tags
}

################################################################################
# DataSync - Data Migration
################################################################################

module "datasync" {
  source = "../../modules/datasync"
  count  = var.enable_datasync ? 1 : 0

  name = local.name

  vpc_id          = module.vpc_onprem.vpc_id
  agent_subnet_id = module.vpc_onprem.private_subnet_ids[0]

  source_cidrs      = [module.vpc_onprem.vpc_cidr_block]
  create_nfs_source = false # Set to true when NFS server is available

  # VPC endpoint for private activation (no public IP needed)
  create_vpc_endpoint     = true
  vpc_endpoint_subnet_ids = module.vpc_onprem.private_subnet_ids

  bandwidth_limit_bytes_per_second = 104857600 # 100 MB/s
  schedule_expression              = "cron(0 * * * ? *)"

  tags = local.tags
}

################################################################################
# Transfer Family - Partner SFTP
################################################################################

module "transfer_family" {
  source = "../../modules/transfer-family"
  count  = var.enable_transfer_family ? 1 : 0

  name = local.name

  endpoint_type = "PUBLIC" # Use VPC for production
  users         = var.sftp_users

  tags = local.tags
}

################################################################################
# ECS Fargate - Application Layer
################################################################################

module "ecs_fargate" {
  source = "../../modules/ecs-fargate"

  name = local.name

  vpc_id             = module.vpc_prod.vpc_id
  public_subnet_ids  = module.vpc_prod.public_subnet_ids
  private_subnet_ids = module.vpc_prod.private_subnet_ids

  container_image = var.app_container_image
  container_port  = var.app_container_port
  cpu             = 256
  memory          = 512
  desired_count   = 2

  health_check_path = "/"

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "DB_HOST"
      value = module.aurora.cluster_endpoint
    }
  ]

  secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.aurora.secret_arn}:password::"
    }
  ]

  secrets_manager_arns = [module.aurora.secret_arn]

  enable_autoscaling = true
  min_capacity       = 1
  max_capacity       = 4

  tags = local.tags
}

################################################################################
# Aurora PostgreSQL - Database Layer
################################################################################

module "aurora" {
  source = "../../modules/aurora"

  name = local.name

  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.private_subnet_ids

  engine_version = "16.8"
  database_name  = "app"

  min_capacity = var.aurora_min_capacity
  max_capacity = var.aurora_max_capacity

  instance_count = 2  # Writer + reader for HA demo

  allowed_security_groups = [module.ecs_fargate.ecs_security_group_id]

  create_global_cluster = true # Enable for DR

  deletion_protection = false
  skip_final_snapshot = true

  tags = local.tags
}

################################################################################
# Monitoring - CloudWatch + CloudTrail
################################################################################

module "monitoring" {
  source = "../../modules/monitoring"

  name = local.name

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  ecs_cluster_name   = module.ecs_fargate.cluster_name
  aurora_cluster_id  = module.aurora.cluster_identifier
  alb_arn_suffix     = replace(module.ecs_fargate.alb_arn, "/.*:loadbalancer\\//", "")

  approved_regions = [var.primary_region, var.dr_region]

  tags = local.tags
}
