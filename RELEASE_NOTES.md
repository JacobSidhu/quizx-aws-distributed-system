# Release Notes

## v2.0.0

- Split the runtime across dedicated Question App and Submit App EC2 instances.
- Added RabbitMQ durable messaging for submitted questions.
- Added an ETL consumer that persists RabbitMQ messages into MySQL.
- Added private-IP service integration and security-group-to-security-group rules.
- Added parallel GitHub Actions deployment jobs, health checks, ETL verification, integration testing, and deployment summaries.
- Added an encrypted, versioned S3 Terraform state backend for the new AWS account.

Known release notes:

- Public application endpoints use HTTP without TLS.
- GitHub Actions uses long-lived AWS access-key secrets; GitHub OIDC is the recommended next improvement.
- The deployment uses SSH and public EC2 instances for learning visibility.

## v1.0.0

- Added Terraform infrastructure for a single EC2 foundation release.
- Added Docker Compose runtime for Question App, Submit App, and private MySQL.
- Added GitHub Actions validation, Terraform apply/destroy workflow, and SSH app deployment to EC2.
- Added application screenshots, Terraform evidence, and v1 test evidence.
- Added security, cost, architecture, and learning notes for the release.

Known release note:

- The deploy workflow uses SSH with a repository secret for v1.0.0. A later production-style version should replace this with a more robust deployment mechanism.
