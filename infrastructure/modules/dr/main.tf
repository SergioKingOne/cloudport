################################################################################
# DR Module
# Route 53 failover routing with health checks and Global Accelerator
################################################################################

data "aws_region" "current" {}

################################################################################
# Route 53 Health Checks
################################################################################

resource "aws_route53_health_check" "primary" {
  count = var.create_health_checks ? 1 : 0

  fqdn              = var.primary_endpoint
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval

  tags = merge(var.tags, {
    Name = "${var.name}-primary-health-check"
  })
}

resource "aws_route53_health_check" "secondary" {
  count = var.create_health_checks && var.create_secondary_resources ? 1 : 0

  fqdn              = var.secondary_endpoint
  port              = var.health_check_port
  type              = var.health_check_type
  resource_path     = var.health_check_path
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval

  tags = merge(var.tags, {
    Name = "${var.name}-secondary-health-check"
  })
}

################################################################################
# Route 53 Hosted Zone (Optional)
################################################################################

resource "aws_route53_zone" "this" {
  count = var.create_hosted_zone ? 1 : 0

  name    = var.domain_name
  comment = "Managed by Terraform - ${var.name}"

  tags = var.tags
}

locals {
  zone_id = var.create_hosted_zone ? aws_route53_zone.this[0].zone_id : var.hosted_zone_id
}

################################################################################
# Route 53 Failover Records
################################################################################

resource "aws_route53_record" "primary" {
  count = local.zone_id != "" && var.primary_endpoint != "" ? 1 : 0

  zone_id = local.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.primary_alb_dns_name
    zone_id                = var.primary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = var.create_health_checks ? aws_route53_health_check.primary[0].id : null
}

resource "aws_route53_record" "secondary" {
  count = local.zone_id != "" && var.create_secondary_resources ? 1 : 0

  zone_id = local.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.secondary_alb_dns_name
    zone_id                = var.secondary_alb_zone_id
    evaluate_target_health = true
  }

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "secondary"
  health_check_id = var.create_health_checks && var.create_secondary_resources ? aws_route53_health_check.secondary[0].id : null
}

################################################################################
# Global Accelerator
################################################################################

resource "aws_globalaccelerator_accelerator" "this" {
  count = var.create_global_accelerator ? 1 : 0

  name            = "${var.name}-accelerator"
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = var.enable_flow_logs
    flow_logs_s3_bucket = var.flow_logs_bucket
    flow_logs_s3_prefix = "global-accelerator/"
  }

  tags = var.tags
}

resource "aws_globalaccelerator_listener" "this" {
  count = var.create_global_accelerator ? 1 : 0

  accelerator_arn = aws_globalaccelerator_accelerator.this[0].id
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  count = var.create_global_accelerator && var.primary_alb_arn != "" ? 1 : 0

  listener_arn                  = aws_globalaccelerator_listener.this[0].id
  endpoint_group_region         = var.primary_region
  health_check_interval_seconds = 30
  health_check_path             = var.health_check_path
  health_check_port             = var.health_check_port
  health_check_protocol         = "HTTP"
  threshold_count               = 3
  traffic_dial_percentage       = var.primary_traffic_dial

  endpoint_configuration {
    endpoint_id                    = var.primary_alb_arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  count = var.create_global_accelerator && var.create_secondary_resources ? 1 : 0

  listener_arn                  = aws_globalaccelerator_listener.this[0].id
  endpoint_group_region         = var.secondary_region
  health_check_interval_seconds = 30
  health_check_path             = var.health_check_path
  health_check_port             = var.health_check_port
  health_check_protocol         = "HTTP"
  threshold_count               = 3
  traffic_dial_percentage       = var.secondary_traffic_dial

  endpoint_configuration {
    endpoint_id                    = var.secondary_alb_arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}

################################################################################
# CloudWatch Alarms for Health Checks
################################################################################

resource "aws_cloudwatch_metric_alarm" "primary_health" {
  count = var.create_health_checks ? 1 : 0

  alarm_name          = "${var.name}-primary-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Primary endpoint health check failed"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary[0].id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "secondary_health" {
  count = var.create_health_checks && var.create_secondary_resources ? 1 : 0

  alarm_name          = "${var.name}-secondary-health-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Secondary endpoint health check failed"

  dimensions = {
    HealthCheckId = aws_route53_health_check.secondary[0].id
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = var.tags
}
