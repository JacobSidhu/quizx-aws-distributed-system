# Security Notes

QuizX AWS v2.0.0 is a distributed learning release, so the security model remains intentionally simple and visible.

## Network Access

- SSH is controlled by `allowed_ssh_cidr` in Terraform.
- Question App is exposed on port `4000`.
- Submit App is exposed on port `4200`.
- MySQL is not mapped to a public host port.
- RabbitMQ port `5672` is restricted to traffic from the Question App security group.
- Cross-instance service communication uses private EC2 addresses.
- Containers on each instance communicate over a private Docker network.

## Secret Handling

- Real `.env` files are ignored by Git.
- Real `terraform.tfvars` files are ignored by Git.
- Terraform state files are ignored by Git.
- Private SSH keys and AWS credentials must not be committed.
- GitHub Actions should use repository secrets for AWS and EC2 credentials.

## Current Limitations

- Application ports are public for portfolio demonstration.
- The apps are served over HTTP, not HTTPS.
- GitHub Actions currently use long-lived AWS credentials if configured.
- The RabbitMQ management port is mapped on the host but is not permitted by the AWS security group; use an SSH tunnel for administrative access.
- Later versions should use HTTPS, stronger authentication, rate limiting, private subnets, and GitHub OIDC.
