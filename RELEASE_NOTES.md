# Release Notes

## v3.0.0

- Added the ACM-secured `quizx.lecux.com` API Gateway custom domain.
- Added automated ACM validation and application CNAME management through the
  GoDaddy Domains API.
- Added an API Gateway VPC Link to an internal Application Load Balancer.
- Added separate ALB target groups, health checks, and path rules for the
  Question and Submit services.
- Added two public subnets in separate Availability Zones to support the ALB.
- Added `/question` and `/submit` route prefixes, cross-application navigation,
  and a default redirect from `/` to `/question`.
- Added security-group boundaries between the VPC Link, ALB, applications, and
  RabbitMQ.
- Added a required administrator SSH CIDR deployment input and temporary
  GitHub-runner SSH rules with failure-safe cleanup.
- Added automated HTTPS custom-domain verification to the deployment workflow.
- Updated compatible Node.js dependency lockfiles to resolve reported
  production dependency advisories.

Verification notes:

- Release candidate `7e2d638d2900d7bb9e390fc1209baa7fd029983b`
  passed CI, Docker builds, Terraform validation and planning, infrastructure
  apply, parallel application deployment, private app integration, HTTPS
  routing, manual submission and persistence verification, security checks, and
  infrastructure destruction.
- Evidence is recorded in `docs/testing/v3-test-evidence.md` with links to CI
  run #68, apply/deployment run #114, and destroy run #115.
- Merge and the `v3.0.0` tag remain intentionally pending.

Known limitations:

- EC2 instances remain in public subnets and expose direct HTTP application
  ports only to configured CIDRs.
- Deployment uses SSH and long-lived AWS access-key secrets.
- MySQL and RabbitMQ are self-managed Docker containers.
- Runtime secrets are supplied through GitHub Actions rather than AWS Secrets
  Manager or Parameter Store.
- Authentication, authorization, rate limiting, WAF, and centralized
  observability are not yet implemented.

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
