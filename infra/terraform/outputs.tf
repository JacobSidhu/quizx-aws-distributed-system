output "question_app_ec2_instance_id" {
  description = "ID of the EC2 instance running the QuizX application"
  value       = aws_instance.question_app.id
}

output "question_app_ec2_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.question_app.public_ip
}

output "question_app_ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.question_app.public_dns
}

output "question_app_ec2_private_ip" {
  description = "Private IPv4 address of the EC2 instance running the question app"
  value       = aws_instance.question_app.private_ip
}

output "question_app_ssh_command" {
  description = "SSH command for connecting to the EC2 instance"
  value       = "ssh -i <private-key-path> ubuntu@${aws_instance.question_app.public_ip}"
}

output "question_app_url" {
  description = "Public URL for the QuizX question application"
  value       = "http://${aws_instance.question_app.public_ip}:${var.question_app_port}"
}

output "question_app_security_group_id" {
  description = "ID of the security group attached to the EC2 instance"
  value       = aws_security_group.question_app_sg.id
}

//----Submit App Outputs

output "submit_app_ec2_instance_id" {
  description = "ID of the EC2 instance running the QuizX application"
  value       = aws_instance.submit_app.id
}

output "submit_app_ec2_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.submit_app.public_ip
}

output "submit_app_ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.submit_app.public_dns
}

output "submit_app_ec2_private_ip" {
  description = "Private IPv4 address of the EC2 instance running the submit app and RabbitMQ"
  value       = aws_instance.submit_app.private_ip
}

output "submit_app_ssh_command" {
  description = "SSH command for connecting to the EC2 instance"
  value       = "ssh -i <private-key-path> ubuntu@${aws_instance.submit_app.public_ip}"
}

output "submit_app_url" {
  description = "Public URL for the QuizX submit application"
  value       = "http://${aws_instance.submit_app.public_ip}:${var.submit_app_port}"
}

output "submit_app_security_group_id" {
  description = "ID of the security group attached to the EC2 instance"
  value       = aws_security_group.submit_app_sg.id
}

//----Common Outputs

output "vpc_id" {
  description = "ID of the VPC created for QuizX"
  value       = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "ID of the public subnet containing the Question appEC2 instance"
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "ID of the public subnet containing the Submit appEC2 instance"
  value       = aws_subnet.public_2.id
}

output "key_pair_name" {
  description = "Name of the AWS key pair attached to the EC2 instance"
  value       = aws_key_pair.quizx_key.key_name
}

output "acm_validation_records" {
  description = "DNS records published to GoDaddy by the deployment workflow"
  value = var.enable_custom_domain ? {
    for option in aws_acm_certificate.api[0].domain_validation_options :
    option.domain_name => {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  } : {}
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate for the custom API domain"
  value       = try(aws_acm_certificate.api[0].arn, null)
}

output "api_gateway_domain_target" {
  description = "API Gateway hostname published as a CNAME in GoDaddy"
  value       = try(aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].target_domain_name, null)
}

output "api_custom_url" {
  description = "HTTPS URL for the QuizX API custom domain"
  value       = var.enable_custom_domain ? "https://${local.api_fqdn}" : null
}
