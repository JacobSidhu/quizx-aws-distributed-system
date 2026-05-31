output "ec2_instance_id" {
  description = "ID of the EC2 instance running the QuizX application"
  value       = aws_instance.web.id
}

output "ec2_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "ssh_command" {
  description = "SSH command for connecting to the EC2 instance"
  value       = "ssh -i <private-key-path> ubuntu@${aws_instance.web.public_ip}"
}

output "question_app_url" {
  description = "Public URL for the QuizX question application"
  value       = "http://${aws_instance.web.public_ip}:${var.question_app_port}"
}

output "submit_app_url" {
  description = "Public URL for the QuizX submit application"
  value       = "http://${aws_instance.web.public_ip}:${var.submit_app_port}"
}

output "vpc_id" {
  description = "ID of the VPC created for QuizX"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet containing the EC2 instance"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the security group attached to the EC2 instance"
  value       = aws_security_group.quizx_sg.id
}

output "key_pair_name" {
  description = "Name of the AWS key pair attached to the EC2 instance"
  value       = aws_key_pair.quizx_key.key_name
}
