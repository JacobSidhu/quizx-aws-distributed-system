# ==============================================================================
# EC2 application servers
# ==============================================================================
# The question and submit apps each run on their own instance, one per public
# subnet and availability zone. user-data.sh installs Docker; the deployment
# workflow then starts the containers over SSH.
#
# The instances have public IPs and route through the internet gateway. This
# is the current runtime path while the services move to EKS (see eks.tf);
# application traffic still enters only through API Gateway and the ALB.
# ==============================================================================
resource "aws_instance" "question_app" {
  ami                         = var.aws_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.question_app_sg.id]

  key_name = aws_key_pair.quizx_key.key_name

  user_data = file("${path.module}/user-data.sh")

  tags = local.common_tags
}

resource "aws_instance" "submit_app" {
  ami                         = var.aws_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_2.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.submit_app_sg.id]

  key_name = aws_key_pair.quizx_key.key_name

  user_data = file("${path.module}/user-data.sh")

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# SSH key pair
# ------------------------------------------------------------------------------
# Registers the operator's public key; the private key never leaves the
# operator or the deployment workflow's secrets.
# ------------------------------------------------------------------------------
resource "aws_key_pair" "quizx_key" {
  key_name   = local.ec2_key_name
  public_key = var.ssh_public_key

  tags = local.common_tags
}
