# ==============================================================================
# Security groups
# ==============================================================================
# Traffic path:
#
#   API Gateway VPC link ──► ALB ──► question app / submit app (EC2)
#                                     submit app ──► question app
#                                     question app ──► RDS
#
# Groups are declared without inline rules where traffic flows between groups;
# those rules are separate aws_security_group_rule resources below, which
# avoids circular references between the groups.
# ==============================================================================

# ------------------------------------------------------------------------------
# Base groups (rules defined separately below)
# ------------------------------------------------------------------------------
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

resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${local.name_prefix}-vpc-endpoint-sg"
  description = "Security group for vpc endpoints"
  vpc_id      = aws_vpc.main.id
  tags        = local.common_tags
}

# ------------------------------------------------------------------------------
# Application servers (SSH and app port from the configured CIDRs)
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# VPC link to ALB, and ALB to the applications
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Application ingress, app-to-app, and app-to-database access
# ------------------------------------------------------------------------------
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

# HTTPS from anywhere in the VPC to the interface endpoints.
resource "aws_security_group_rule" "vpc_endpoint_sg_rules" {
  type              = "ingress"
  description       = "Aloow HTTPS from resources inside the VPC"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.networking.vpc_cidr]
  security_group_id = aws_security_group.vpc_endpoint_sg.id
}
