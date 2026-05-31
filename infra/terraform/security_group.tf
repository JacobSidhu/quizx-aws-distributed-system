resource "aws_security_group" "quizx_sg" {

  name        = "quizx-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH from my IP"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Allow HTTP access to app"
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


resource "aws_key_pair" "quizx_key" {
  key_name   = "${var.project_name}-ec2-key"
  public_key = file(var.ssh_public_key_path)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-key"
  })
}