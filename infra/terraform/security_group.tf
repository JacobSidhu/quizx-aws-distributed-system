resource "aws_security_group" "question_app_sg" {

  name        = "question-app-sg"
  description = "Allow HTTP and SSH traffic for question app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from my IP"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Allow HTTP access to question app"
    from_port   = var.question_app_port
    to_port     = var.question_app_port
    protocol    = "tcp"
    cidr_blocks = [var.question_app_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-web"
  })
}

resource "aws_security_group" "submit_app_sg" {
  name        = "submit-app-sg"
  description = "Allow HTTP and SSH traffic for submit app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from my IP"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Allow HTTP access to submit app"
    from_port   = var.submit_app_port
    to_port     = var.submit_app_port
    protocol    = "tcp"
    cidr_blocks = [var.submit_app_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "question_app_from_submit_app" {
  type                     = "ingress"
  description              = "Allow submit app EC2 to read question app categories"
  from_port                = var.question_app_port
  to_port                  = var.question_app_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.question_app_sg.id
  source_security_group_id = aws_security_group.submit_app_sg.id
}

resource "aws_security_group_rule" "rabbitmq_from_question_app" {
  type                     = "ingress"
  description              = "Allow ETL consumer on question app EC2 to consume RabbitMQ"
  from_port                = var.rabbitmq_port
  to_port                  = var.rabbitmq_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.submit_app_sg.id
  source_security_group_id = aws_security_group.question_app_sg.id
}

// ----------------------------------------------------------
// Security group for VPC link
// ----------------------------------------------------------
resource "aws_security_group" "vpc_link_sg" {
  name        = "vpc-link-sg"
  description = "Security group for VPC link"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow traffic from API Gateway to ALB"
    from_port       = var.vpc_link_to_alb_port
    to_port         = var.vpc_link_to_alb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
}
// ----------------------------------------------------------
// Security Group for ALB
// ----------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP traffic from VPC link"
    from_port       = var.alb_port
    to_port         = var.alb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_link_sg.id]
  }
}
