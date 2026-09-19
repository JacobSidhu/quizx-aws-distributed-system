# Security Notes

QuizX AWS v3.0.0 is a learning deployment with a public HTTPS entry point and
explicit security-group boundaries around the private integration path.

## Public Boundary

- `quizx.lecux.com` is served through an Amazon API Gateway custom domain.
- AWS Certificate Manager supplies and validates the TLS certificate.
- The Application Load Balancer is internal rather than internet-facing.
- API Gateway reaches the ALB through a VPC Link.
- The ALB accepts port `80` from the VPC Link security group only.
- The ALB forwards `/question/*` and `/submit/*` to separate target groups.

## Application and Data Access

- Question App port `4000` accepts the ALB, the Submit App security group, and
  the explicitly configured diagnostic CIDR.
- Submit App port `4200` accepts the ALB and the explicitly configured
  diagnostic CIDR.
- RabbitMQ port `5672` accepts the Question App security group so the ETL
  consumer can connect over private EC2 addresses.
- RabbitMQ management port `15672` is mapped by Docker but is not allowed by the
  AWS security group; administration should use an SSH tunnel when required.
- MySQL has no host-port mapping and is reachable only through its Docker
  network.
- Containers on each EC2 instance communicate through a private Docker network.

## SSH Controls

- Persistent administrator access is controlled by the required
  `allowed_ssh_cidr` deployment input and Terraform variable.
- A single trusted public IPv4 `/32` should be used whenever possible.
- Each GitHub-hosted deployment or integration runner determines its current
  public IP and receives a temporary `/32` ingress rule.
- Cleanup steps revoke runner rules even when deployment or verification fails.
- The workflow records whether it created a rule so it does not remove a
  pre-existing administrator rule with the same CIDR.

## Secret and State Handling

- Real `.env` and `terraform.tfvars` files are ignored by Git.
- Terraform plans, state, private keys, and AWS credentials must not be
  committed.
- Terraform state is stored in an encrypted S3 backend.
- AWS credentials, the EC2 deployment key, database passwords, RabbitMQ
  password, and GoDaddy token are supplied through GitHub Actions secrets.
- `GO_DADDY_DNS_TOKEN` should contain only the Personal Access Token value.
- The GoDaddy token should have only `domains.domain:read` and
  `domains.dns:update` permissions.
- Workflow output and evidence must not include secret values or Terraform
  state contents.

## DNS Safety

The DNS helper modifies a record set only through the GoDaddy Domains API. On
destroy, it removes a managed record only when the current DNS value still
matches the Terraform-derived value, reducing the risk of deleting an unrelated
record that was changed outside the workflow.

## Current Limitations

- Both EC2 instances remain in public subnets for learning visibility.
- Direct EC2 application ports can be enabled for configured CIDRs and use HTTP;
  normal users should use the API Gateway HTTPS endpoint.
- Deployment still uses SSH and a repository-stored private-key secret.
- GitHub Actions uses long-lived AWS access keys rather than OIDC federation.
- Runtime passwords are GitHub secrets passed into Docker rather than values
  retrieved from AWS Secrets Manager or Parameter Store.
- The public API does not yet implement authentication, authorization, rate
  limiting, or AWS WAF.
- Centralized security logging, alerting, and automated vulnerability scanning
  are not yet implemented.

Recommended future work includes private application subnets, GitHub OIDC,
immutable image-based deployment, managed secrets, API authentication, WAF or
rate limiting, centralized observability, and routine dependency/container
scanning.
