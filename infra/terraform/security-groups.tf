// -----------------------------------------------------------
// Base security groups --------------------------------------
// -----------------------------------------------------------
resource "aws_security_group" "vpc_link_sg" {
  name        = "${local.name_prefix}-vpc-link-sg"
  description = "Security group for the API Gateway VPC link"
  vpc_id      = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_security_group" "alb_sg" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for the ALB"
  vpc_id      = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_security_group" "rds_sg" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for the RDS instance"
  vpc_id      = aws_vpc.main.id

  tags = local.common_tags
}
// -----------------------------------------------------------
// Question app security group -------------------------------
// -----------------------------------------------------------
resource "aws_security_group" "question_app_sg" {
  name        = "${local.name_prefix}-question-app-sg"
  description = "Allow SSH, ALB access, and app-to-app traffic for the question app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from admin CIDR"
    from_port   = var.service_ports.ssh
    to_port     = var.service_ports.ssh
    protocol    = "tcp"
    cidr_blocks = [var.access.ssh_cidr]
  }

  ingress {
    description = "Allow HTTP access to the question app from the public CIDR"
    from_port   = var.service_ports.question_app
    to_port     = var.service_ports.question_app
    protocol    = "tcp"
    cidr_blocks = [var.access.question_app_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
// -----------------------------------------------------------
// Submit app security group ---------------------------------
// -----------------------------------------------------------
resource "aws_security_group" "submit_app_sg" {
  name        = "${local.name_prefix}-submit-app-sg"
  description = "Allow SSH, ALB access, and app-to-app traffic for the submit app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from admin CIDR"
    from_port   = var.service_ports.ssh
    to_port     = var.service_ports.ssh
    protocol    = "tcp"
    cidr_blocks = [var.access.ssh_cidr]
  }

  ingress {
    description = "Allow HTTP access to the submit app from the public CIDR"
    from_port   = var.service_ports.submit_app
    to_port     = var.service_ports.submit_app
    protocol    = "tcp"
    cidr_blocks = [var.access.submit_app_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}
// -----------------------------------------------------------
// ALB and VPC link traffic ----------------------------------
// -----------------------------------------------------------
resource "aws_security_group_rule" "vpc_link_to_alb_egress" {
  type                     = "egress"
  description              = "Allow the VPC link to reach the ALB"
  from_port                = var.service_ports.vpc_link
  to_port                  = var.service_ports.alb
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_link_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "vpc_link_to_alb_ingress" {
  type                     = "ingress"
  description              = "Allow the VPC link to send traffic to the ALB"
  from_port                = var.service_ports.vpc_link
  to_port                  = var.service_ports.alb
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.vpc_link_sg.id
}

resource "aws_security_group_rule" "alb_to_question_app_egress" {
  type                     = "egress"
  description              = "Allow the ALB to reach the question app"
  from_port                = var.service_ports.alb
  to_port                  = var.service_ports.question_app
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.question_app_sg.id
}

resource "aws_security_group_rule" "alb_to_submit_app_egress" {
  type                     = "egress"
  description              = "Allow the ALB to reach the submit app"
  from_port                = var.service_ports.alb
  to_port                  = var.service_ports.submit_app
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.submit_app_sg.id
}
// -----------------------------------------------------------
// App-to-app and app-to-service access ----------------------
// -----------------------------------------------------------
resource "aws_security_group_rule" "question_app_from_alb" {
  type                     = "ingress"
  description              = "Allow the ALB to access the question app"
  from_port                = var.service_ports.question_app
  to_port                  = var.service_ports.question_app
  protocol                 = "tcp"
  security_group_id        = aws_security_group.question_app_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "submit_app_from_alb" {
  type                     = "ingress"
  description              = "Allow the ALB to access the submit app"
  from_port                = var.service_ports.submit_app
  to_port                  = var.service_ports.submit_app
  protocol                 = "tcp"
  security_group_id        = aws_security_group.submit_app_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "question_app_from_submit_app" {
  type                     = "ingress"
  description              = "Allow the submit app to read question app categories"
  from_port                = var.service_ports.question_app
  to_port                  = var.service_ports.question_app
  protocol                 = "tcp"
  security_group_id        = aws_security_group.question_app_sg.id
  source_security_group_id = aws_security_group.submit_app_sg.id
}

resource "aws_security_group_rule" "question_app_to_rds" {
  type                     = "ingress"
  description              = "Allow the question app to access the RDS instance"
  from_port                = var.service_ports.rds
  to_port                  = var.service_ports.rds
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.question_app_sg.id
}