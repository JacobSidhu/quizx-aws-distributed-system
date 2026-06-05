# Security Notes

QuizX AWS v1.0.0 is a foundation release, so the security model is intentionally simple and visible.

## Network Access

- SSH is controlled by `allowed_ssh_cidr` in Terraform.
- Question App is exposed on port `4000`.
- Submit App is exposed on port `4200`.
- MySQL is not mapped to a public host port.
- Containers communicate over the private Docker network `quizx-docker-network`.

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
- Later versions should use HTTPS, stronger auth, rate limiting, and GitHub OIDC.
