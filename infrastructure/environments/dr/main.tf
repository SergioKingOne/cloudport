################################################################################
# DR Environment - Disaster Recovery Configuration
################################################################################

locals {
  name = "${var.project_name}-${var.environment}-dr"
  tags = merge(var.common_tags, {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "disaster-recovery"
  })
}

################################################################################
# DR VPC
################################################################################

module "vpc_dr" {
  source = "../../modules/vpc"

  name               = local.name
  cidr_block         = "10.10.0.0/16"
  az_count           = 2
  create_nat_gateway = true
  single_nat_gateway = true
  enable_flow_logs   = true

  tags = local.tags
}

################################################################################
# DR ECS Fargate Application
################################################################################

module "ecs_fargate_dr" {
  source = "../../modules/ecs-fargate"
  count  = var.enable_dr_app ? 1 : 0

  name = local.name

  vpc_id             = module.vpc_dr.vpc_id
  public_subnet_ids  = module.vpc_dr.public_subnet_ids
  private_subnet_ids = module.vpc_dr.private_subnet_ids

  container_image = var.app_container_image
  container_port  = 80
  cpu             = 256
  memory          = 512
  desired_count   = 1 # Minimal for DR standby

  health_check_path = "/"

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = "${var.environment}-dr"
    },
    {
      name  = "DB_HOST"
      value = module.aurora_dr.cluster_endpoint
    }
  ]

  secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = "${module.aurora_dr.secret_arn}:password::"
    }
  ]

  secrets_manager_arns = [module.aurora_dr.secret_arn]

  enable_autoscaling = true
  min_capacity       = 1
  max_capacity       = 5

  tags = local.tags
}

################################################################################
# Aurora DR (Secondary Cluster)
################################################################################

module "aurora_dr" {
  source = "../../modules/aurora"

  name = local.name

  vpc_id     = module.vpc_dr.vpc_id
  subnet_ids = module.vpc_dr.private_subnet_ids

  engine_version = "15.4"

  min_capacity = var.aurora_min_capacity
  max_capacity = var.aurora_max_capacity

  instance_count = 1 # Minimal for DR

  allowed_security_groups = var.enable_dr_app ? [module.ecs_fargate_dr[0].ecs_security_group_id] : []

  # Global database configuration
  global_cluster_identifier = var.global_cluster_id
  is_secondary              = var.global_cluster_id != ""

  deletion_protection = false
  skip_final_snapshot = true

  tags = local.tags
}

################################################################################
# DR Routing (Route 53 + Global Accelerator)
################################################################################

module "dr_routing" {
  source = "../../modules/dr"

  name = var.project_name

  # Health checks
  create_health_checks = true
  primary_endpoint     = var.primary_alb_dns_name
  secondary_endpoint   = var.enable_dr_app ? module.ecs_fargate_dr[0].alb_dns_name : ""

  # ALB configuration for failover
  primary_alb_dns_name   = var.primary_alb_dns_name
  primary_alb_zone_id    = var.primary_alb_zone_id
  primary_alb_arn        = var.primary_alb_arn
  secondary_alb_dns_name = var.enable_dr_app ? module.ecs_fargate_dr[0].alb_dns_name : ""
  secondary_alb_zone_id  = var.enable_dr_app ? module.ecs_fargate_dr[0].alb_zone_id : ""
  secondary_alb_arn      = var.enable_dr_app ? module.ecs_fargate_dr[0].alb_arn : ""

  # Global Accelerator
  create_global_accelerator = var.enable_global_accelerator
  primary_region            = var.primary_region
  secondary_region          = var.dr_region
  primary_traffic_dial      = 100
  secondary_traffic_dial    = 100

  tags = local.tags
}
