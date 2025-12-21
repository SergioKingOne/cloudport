################################################################################
# Security Inspection Module
# Gateway Load Balancer with Suricata IDS for centralized traffic inspection
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
# Gateway Load Balancer
################################################################################

resource "aws_lb" "gwlb" {
  name               = "${var.name}-gwlb"
  load_balancer_type = "gateway"
  subnets            = var.gwlb_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = merge(var.tags, {
    Name = "${var.name}-gwlb"
  })
}

resource "aws_lb_target_group" "suricata" {
  name        = "${var.name}-suricata-tg"
  port        = 6081
  protocol    = "GENEVE"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    port     = 80
    protocol = "HTTP"
    path     = "/health"
  }

  tags = var.tags
}

resource "aws_lb_listener" "gwlb" {
  load_balancer_arn = aws_lb.gwlb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.suricata.arn
  }

  tags = var.tags
}

################################################################################
# VPC Endpoint Service
################################################################################

resource "aws_vpc_endpoint_service" "gwlb" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]

  tags = merge(var.tags, {
    Name = "${var.name}-gwlb-endpoint-service"
  })
}

################################################################################
# GWLB Endpoints in Spoke VPCs
################################################################################

resource "aws_vpc_endpoint" "gwlb" {
  for_each = var.gwlb_endpoints

  service_name      = aws_vpc_endpoint_service.gwlb.service_name
  vpc_id            = each.value.vpc_id
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = each.value.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name}-gwlbe-${each.key}"
  })
}

################################################################################
# Suricata Security Group
################################################################################

resource "aws_security_group" "suricata" {
  name        = "${var.name}-suricata-sg"
  description = "Security group for Suricata IDS instances"
  vpc_id      = var.vpc_id

  # GENEVE traffic from GWLB
  ingress {
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "GENEVE from GWLB"
  }

  # Health check
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Health check"
  }

  # SSH for management (optional)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
    description = "SSH management"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-suricata-sg"
  })
}

################################################################################
# IAM Role for Suricata Instances
################################################################################

resource "aws_iam_role" "suricata" {
  name = "${var.name}-suricata-role"

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

resource "aws_iam_role_policy_attachment" "suricata_ssm" {
  role       = aws_iam_role.suricata.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "suricata_cloudwatch" {
  name = "${var.name}-suricata-cloudwatch"
  role = aws_iam_role.suricata.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_instance_profile" "suricata" {
  name = "${var.name}-suricata-profile"
  role = aws_iam_role.suricata.name

  tags = var.tags
}

################################################################################
# Launch Template for Suricata
################################################################################

resource "aws_launch_template" "suricata" {
  name          = "${var.name}-suricata-lt"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.suricata.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.suricata.id]
    delete_on_termination       = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(templatefile("${path.module}/templates/suricata-userdata.sh", {
    suricata_rules_url = var.suricata_rules_url
    log_group_name     = aws_cloudwatch_log_group.suricata.name
    region             = data.aws_region.current.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name}-suricata"
    })
  }

  tags = var.tags
}

################################################################################
# Auto Scaling Group
################################################################################

resource "aws_autoscaling_group" "suricata" {
  name                = "${var.name}-suricata-asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.suricata_subnet_ids
  target_group_arns   = [aws_lb_target_group.suricata.arn]

  launch_template {
    id      = aws_launch_template.suricata.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-suricata"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

################################################################################
# CloudWatch Log Group for Suricata
################################################################################

resource "aws_cloudwatch_log_group" "suricata" {
  name              = "/aws/suricata/${var.name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "suricata_cpu" {
  alarm_name          = "${var.name}-suricata-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Suricata instance CPU utilization is high"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.suricata.name
  }

  tags = var.tags
}
