# Architecture Explanation

QuizX AWS v1.0.0 runs a multi-container quiz system on a single AWS EC2 instance.

## Infrastructure

Terraform provisions:

- VPC
- Public subnet
- Internet gateway
- Public route table
- Security group
- EC2 instance
- EC2 key pair

The security group allows SSH from a configured CIDR and exposes only the two application ports.

## Runtime

Docker Compose starts three services:

- `quizx-question-app` on public port `4000`
- `quizx-submit-app` on public port `4200`
- `quizx-mysql` on internal port `3306`

The application containers connect to MySQL through Docker DNS using the service name `mysql`.

## Data Persistence

MySQL stores data in the Docker volume `quizx_mysql_data`. Data should remain available after container recreation as long as the volume is not deleted.

## CI/CD

The CI workflow checks Node.js syntax, Docker builds, and Terraform validation.

The deploy workflow automates Terraform apply/destroy. On apply, it reads the EC2 public IP from Terraform outputs, connects to EC2 over SSH, copies the repository files, and starts the application with Docker Compose.
