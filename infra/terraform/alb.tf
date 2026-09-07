// ----------------------------------------------------------
// AWS Application Load Balancer (ALB) configuration                                 
// ----------------------------------------------------------
resource "aws_lb" "quizx_alb" {
  name               = "quizx-alb"
  internal           = true
  load_balancer_type = "application"

  security_groups = [
  aws_security_group.alb_sg.id]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

// ----------------------------------------------------------
// Load Balancer Target Group for ALB
// ----------------------------------------------------------
resource "aws_lb_target_group" "quizx_alb_target_group_question_app" {
  name     = "quizx-alb-tg-question-app"
  port     = var.question_app_port
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
}

resource "aws_lb_target_group" "quizx_alb_target_group_submit_app" {
  name     = "quizx-alb-tg-submit-app"
  port     = var.submit_app_port
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
}

resource "aws_lb_target_group_attachment" "quizx_alb_target_group_attachment_question_app" {
  target_group_arn = aws_lb_target_group.quizx_alb_target_group_question_app.arn
  target_id        = aws_instance.question_app.id
  port             = var.question_app_port
}

resource "aws_lb_target_group_attachment" "quizx_alb_target_group_attachment_submit_app" {
  target_group_arn = aws_lb_target_group.quizx_alb_target_group_submit_app.arn
  target_id        = aws_instance.submit_app.id
  port             = var.submit_app_port
}

// ----------------------------------------------------------
// LB Listener for Quizx ALB
// ----------------------------------------------------------
resource "aws_lb_listener" "quizx_alb_listener" {
  load_balancer_arn = aws_lb.quizx_alb.arn
  port              = var.alb_port
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
  priority     = 100

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
