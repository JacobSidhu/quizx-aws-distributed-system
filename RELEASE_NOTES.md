# Release Notes

## v1.0.0

- Added Terraform infrastructure for a single EC2 foundation release.
- Added Docker Compose runtime for Question App, Submit App, and private MySQL.
- Added GitHub Actions validation, Terraform apply/destroy workflow, and SSH app deployment to EC2.
- Added application screenshots, Terraform evidence, and v1 test evidence.
- Added security, cost, architecture, and learning notes for the release.

Known release note:

- The deploy workflow uses SSH with a repository secret for v1.0.0. A later production-style version should replace this with a more robust deployment mechanism.
