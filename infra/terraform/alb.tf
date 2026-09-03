// ----------------------------------------------------------
// AWS Application Load Balancer (ALB) configuration                                 
// ----------------------------------------------------------
resource "aws_lb" "quizx_alb" {
  name               = "quizx-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups    = [
    aws_security_group.alb_sg.id]

  subnets            = [
    aws_subnet.public_subnet.id,
  ]
}

// ----------------------------------------------------------
// Load Balancer Target Group for ALB
// ----------------------------------------------------------
resource "aws_lb_target_group" "quizx_alb_target_group" {
  name     = "quizx-alb-target-group"
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

resource "aws_lb_target_group_attachment" "quizx_alb_target_group_attachment" {
  target_group_arn = aws_lb_target_group.quizx_alb_target_group.arn
  target_id        = aws_instance.question_app.id
  port             = var.question_app_port
}

resource "aws_lb_listener_rule" "quizx_alb_listener_rule" {
  listener_arn = aws_lb_listener.quizx_alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quizx_alb_target_group.arn
  }

  condition {
    path_pattern {
      values = ["/question"]
    }
  }
}

// ----------------------------------------------------------
// LB Listener for Quizx ALB
// ----------------------------------------------------------
resource "aws_lb_listener" "quizx_alb_listener" {
  load_balancer_arn = aws_lb.quizx_alb.arn
  port              = var.question_app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.quizx_alb_target_group.arn
  }
}
