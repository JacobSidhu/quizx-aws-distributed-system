# Learning Log

## v3.0.0

This release adds a single custom HTTPS boundary and private API Gateway
integration in front of the v2 distributed runtime.

Key learning areas:

- Creating an API Gateway HTTP API with a `$default` proxy route.
- Connecting API Gateway to an internal ALB through a VPC Link.
- Meeting ALB subnet requirements with two Availability Zones.
- Creating path-based listener rules and separate application target groups.
- Issuing an ACM certificate and automating external DNS validation.
- Managing GoDaddy validation and application CNAME records safely through its
  Domains API.
- Making application routes and frontend asset paths work under `/question` and
  `/submit` prefixes.
- Restricting VPC Link, ALB, application, and RabbitMQ traffic with
  security-group references.
- Adding temporary GitHub runner SSH rules and reliable failure cleanup.
- Testing HTTPS, root redirects, path routing, service readiness, deployment,
  and destruction through GitHub Actions.

Lessons from implementation and release review:

- A successful destroy run is not evidence that the same commit completed a
  full apply and integration test; both paths must be recorded separately.
- Release evidence should name the exact tested commit and distinguish automated
  checks from manual end-to-end submission tests.
- Documentation examples must use the same variable names as Terraform.
- External DNS cleanup should be value-aware to avoid removing a record that no
  longer belongs to the deployment.
- Architecture, security, cost, and test documents should be updated together.

## v2.0.0

This release extends the foundation into an event-driven deployment across two EC2 instances.

Key learning areas:

- Publishing durable messages through RabbitMQ.
- Consuming queue messages with a reconnecting ETL service.
- Persisting asynchronously submitted questions in MySQL.
- Connecting workloads through private EC2 addresses and security-group references.
- Deploying independent workloads in parallel with GitHub Actions.
- Verifying health, consumer state, app-to-app integration, and cleanup automatically.
- Moving Terraform state to an encrypted, versioned S3 backend.

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
