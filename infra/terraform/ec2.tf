// Creates EC2 instance
resource "aws_instance" "question_app" {
  ami                         = var.aws_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.question_app_sg.id]

  key_name = aws_key_pair.quizx_key.key_name

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "${var.project_name}-question-app"
  }
}

resource "aws_instance" "submit_app" {
  ami                         = var.aws_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.submit_app_sg.id]

  key_name = aws_key_pair.quizx_key.key_name

  user_data = file("${path.module}/user-data.sh")

  tags = {
    Name = "${var.project_name}-submit-app"
  }
}