# ==============================================================================
# Application Load Balancer
# ==============================================================================
# Internal ALB that receives traffic only from the API Gateway VPC link and
# routes it by path:
#
#   /submit, /submit/*      ──► submit app    (priority 99)
#   /question, /question/*  ──► question app  (priority 100)
#   anything else           ──► question app  (default action)
# ==============================================================================
resource "aws_lb" "quizx_alb" {
  name               = "${local.name_prefix}-alb"
  internal           = true
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Target groups
# ------------------------------------------------------------------------------
# One per application, health-checked on /health.
# ------------------------------------------------------------------------------
resource "aws_lb_target_group" "quizx_alb_target_group_question_app" {
  name     = "${local.name_prefix}-question-app-tg"
  port     = var.service_ports.question_app
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "quizx_alb_target_group_submit_app" {
  name     = "${local.name_prefix}-submit-app-tg"
  port     = var.service_ports.submit_app
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = local.common_tags
}

resource "aws_lb_target_group_attachment" "quizx_alb_target_group_attachment_question_app" {
  target_group_arn = aws_lb_target_group.quizx_alb_target_group_question_app.arn
  target_id        = aws_instance.question_app.id
  port             = var.service_ports.question_app
}

resource "aws_lb_target_group_attachment" "quizx_alb_target_group_attachment_submit_app" {
  target_group_arn = aws_lb_target_group.quizx_alb_target_group_submit_app.arn
  target_id        = aws_instance.submit_app.id
  port             = var.service_ports.submit_app
}

# ------------------------------------------------------------------------------
# Listener and path-based routing rules
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "quizx_alb_listener" {
  load_balancer_arn = aws_lb.quizx_alb.arn
  port              = var.service_ports.alb
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quizx_alb_target_group_question_app.arn
  }
}

resource "aws_lb_listener_rule" "quizx_alb_listener_rule_question_app" {
  listener_arn = aws_lb_listener.quizx_alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quizx_alb_target_group_question_app.arn
  }

  condition {
    path_pattern {
      values = ["/question", "/question/*"]
    }
  }
}

resource "aws_lb_listener_rule" "quizx_alb_listener_rule_submit_app" {
  listener_arn = aws_lb_listener.quizx_alb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quizx_alb_target_group_submit_app.arn
  }

  condition {
    path_pattern {
      values = ["/submit", "/submit/*"]
    }
  }
}
