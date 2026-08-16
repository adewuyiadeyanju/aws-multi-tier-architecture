resource "aws_lb" "fieldops" {
  name               = "fieldops-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "fieldops-${var.environment}-alb"
  }
}

resource "aws_lb_target_group" "application" {
  name     = "fieldops-${var.environment}-tg"
  port     = 8080
  protocol = "HTTP"

  vpc_id = aws_vpc.fieldops.id

  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/health"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "fieldops-${var.environment}-target-group"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.fieldops.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application.arn
  }

  tags = {
    Name = "fieldops-${var.environment}-http-listener"
  }
}