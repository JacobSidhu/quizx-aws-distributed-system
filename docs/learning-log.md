# Learning Log

## v1.0.0

This release demonstrates the foundation of an AWS-hosted distributed-system portfolio project.

Key learning areas:

- Structuring a professional cloud project repository.
- Running multiple Node.js services with Docker Compose.
- Connecting app containers to a private MySQL container through Docker DNS.
- Persisting database data with a Docker volume.
- Provisioning EC2 networking resources with Terraform.
- Restricting SSH with security group CIDR rules.
- Exposing only required application ports.
- Validating app, Docker, and Terraform code through GitHub Actions.
- Capturing screenshots and command evidence for release documentation.

Lessons from release review:

- Screenshots are valuable, but they should be paired with written test evidence.
- README commands must match the actual implemented API routes.
- Release docs should describe what automation currently does, not what is planned.
- Private planning files should remain untracked when they are not intended for GitHub.
