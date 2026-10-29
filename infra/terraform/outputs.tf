# ==============================================================================
# Outputs
# ==============================================================================
# Read by the deployment workflow (instance addresses, ACM and API Gateway
# domain values) and by operators. Output names are part of that contract;
# rename them only together with .github/workflows/deploy.yml.
# ==============================================================================

# ------------------------------------------------------------------------------
# Question app
# ------------------------------------------------------------------------------
output "question_app_ec2_instance_id" {
  description = "ID of the EC2 instance running the question app"
  value       = aws_instance.question_app.id
}

output "question_app_ec2_public_ip" {
  description = "Public IPv4 address of the question app instance"
  value       = aws_instance.question_app.public_ip
}

output "question_app_ec2_public_dns" {
  description = "Public DNS name of the question app instance"
  value       = aws_instance.question_app.public_dns
}

output "question_app_ec2_private_ip" {
  description = "Private IPv4 address of the question app instance"
  value       = aws_instance.question_app.private_ip
}

output "question_app_ssh_command" {
  description = "SSH command for the question app instance"
  value       = "ssh -i <private-key-path> ubuntu@${aws_instance.question_app.public_ip}"
}

output "question_app_url" {
  description = "Direct URL of the question app (reachable only from access.question_app_cidr)"
  value       = "http://${aws_instance.question_app.public_ip}:${var.service_ports.question_app}"
}

output "question_app_security_group_id" {
  description = "ID of the question app security group"
  value       = aws_security_group.question_app_sg.id
}

# ------------------------------------------------------------------------------
# Submit app
# ------------------------------------------------------------------------------
output "submit_app_ec2_instance_id" {
  description = "ID of the EC2 instance running the submit app"
  value       = aws_instance.submit_app.id
}

output "submit_app_ec2_public_ip" {
  description = "Public IPv4 address of the submit app instance"
  value       = aws_instance.submit_app.public_ip
}

output "submit_app_ec2_public_dns" {
  description = "Public DNS name of the submit app instance"
  value       = aws_instance.submit_app.public_dns
}

output "submit_app_ec2_private_ip" {
  description = "Private IPv4 address of the submit app instance"
  value       = aws_instance.submit_app.private_ip
}

output "submit_app_ssh_command" {
  description = "SSH command for the submit app instance"
  value       = "ssh -i <private-key-path> ubuntu@${aws_instance.submit_app.public_ip}"
}

output "submit_app_url" {
  description = "Direct URL of the submit app (reachable only from access.submit_app_cidr)"
  value       = "http://${aws_instance.submit_app.public_ip}:${var.service_ports.submit_app}"
}

output "submit_app_security_group_id" {
  description = "ID of the submit app security group"
  value       = aws_security_group.submit_app_sg.id
}

# ------------------------------------------------------------------------------
# Network and access
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the QuizX VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "ID of the first public subnet (question app instance)"
  value       = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "ID of the second public subnet (submit app instance)"
  value       = aws_subnet.public_2.id
}

output "key_pair_name" {
  description = "Name of the EC2 key pair attached to both instances"
  value       = aws_key_pair.quizx_key.key_name
}

# ------------------------------------------------------------------------------
# Custom domain (null or empty when enable_custom_domain is false)
# ------------------------------------------------------------------------------
output "acm_validation_records" {
  description = "ACM DNS validation records that the deployment workflow publishes to GoDaddy"
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
  description = "API Gateway hostname that the deployment workflow publishes as a CNAME in GoDaddy"
  value       = try(aws_apigatewayv2_domain_name.api[0].domain_name_configuration[0].target_domain_name, null)
}

output "api_custom_url" {
  description = "HTTPS URL of the QuizX API on the custom domain"
  value       = var.enable_custom_domain ? "https://${local.api_fqdn}" : null
}
