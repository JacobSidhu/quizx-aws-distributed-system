# QuizX infrastructure (main stack)

This Terraform stack provisions the QuizX platform on AWS: networking, the
API entry point, the application servers, data services, and the EKS cluster
the services are moving to.

It runs **after** [`infra/bootstrap`](../bootstrap/), which creates the IAM
roles this stack depends on. This stack never creates or modifies IAM itself.

## Architecture

```text
client
  │ HTTPS (optional custom domain via ACM)
  ▼
API Gateway (HTTP API, $default route)
  │ VPC link
  ▼
Internal ALB ──► /submit*   ──► submit app   (EC2, public subnet 2)
             ──► /question* ──► question app (EC2, public subnet 1) ──► RDS MySQL
             ──► default    ──► question app

Private subnets (no internet route, no NAT):
  RDS MySQL · EKS cluster + managed node group · VPC endpoints (EC2, ECR, S3)

Also: SQS queues (submit app, moderate) · ECR repository
```

| Layer       | Resources                                                                  | File(s)                    |
| ----------- | -------------------------------------------------------------------------- | -------------------------- |
| Network     | VPC, 2 public + 2 private subnets in 2 AZs, internet gateway, route tables | `vpc.tf`, `subnets.tf`     |
| Private AWS | Interface endpoints (EC2, ECR API, ECR DKR) and an S3 gateway endpoint     | `vpc.tf`                   |
| Security    | Security groups chained VPC link → ALB → apps → RDS                        | `security-groups.tf`       |
| Entry point | HTTP API, VPC link, internal ALB with path-based routing                   | `api-gateway.tf`, `alb.tf` |
| Domain      | Optional ACM certificate and API Gateway custom domain (DNS at GoDaddy)    | `domain.tf`                |
| Compute     | Question and submit app instances, SSH key pair                            | `ec2.tf`, `user-data.sh`   |
| Data        | RDS MySQL, SQS queues                                                      | `rds.tf`, `sqs.tf`         |
| Containers  | Private EKS cluster, managed node group, ECR repository                    | `eks.tf`, `ecr.tf`         |

## Design notes

- **Assumed execution role.** The provider assumes the Terraform execution
  role from `infra/bootstrap`. Its permissions are scoped per service, to the
  deployment region, to `<project>-<environment>-*` names, and to the standard
  tags, so the provider's `default_tags` must stay in place.
- **No public ALB.** The ALB is internal. The only public entry point is API
  Gateway, which reaches the ALB through a VPC link.
- **Private EKS without NAT.** The EKS API endpoint is private only, and nodes
  run in private subnets with no internet route. They join the cluster and
  pull images through VPC endpoints, so the node group waits for those
  endpoints before it is created.
- **IAM from bootstrap.** EKS cluster and node role ARNs are read from the
  bootstrap state with `terraform_remote_state`.

## Current state and known trade-offs

This stack reflects a migration in progress and is configured for
development:

- **EC2 still serves the applications.** The question and submit apps run on
  EC2 instances in the public subnets, with public IPs and a route through the
  internet gateway, while the services move to EKS. Application traffic still
  enters through API Gateway and the ALB; direct access to the app ports and
  SSH is limited to the CIDRs in `var.access`.
- **Development data settings.** RDS is single-AZ with unencrypted storage, no
  deletion protection, one day of backups, and no final snapshot.
- **Small instance sizes.** EC2, RDS, and the EKS nodes use `t3.micro`-class
  instances.

## Running it

### Prerequisites

1. `infra/bootstrap` has been applied (execution role and EKS roles exist).
2. Credentials for an identity that the execution role trusts.

### Commands

```bash
cd infra/terraform
cp backend.hcl.example backend.hcl            # fill in the state bucket and key
cp terraform.tfvars.example terraform.tfvars  # fill in account, AMI, keys, CIDRs
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

`backend.hcl`, `terraform.tfvars`, and plan files contain account details and
secrets and are git-ignored. Commit only the `.example` templates.

### Order of operations

- **Deploy:** `infra/bootstrap` first, then this stack.
- **Teardown:** this stack first, then `infra/bootstrap`. The EKS node group
  holds the bootstrap node role through an instance profile, so bootstrap
  cannot be destroyed while this stack exists.

## Inputs and outputs

Inputs are documented in [`variables.tf`](variables.tf); required ones without
defaults are `aws_account_id`, `terraform_execution_role_name`,
`public_route_config`, `access`, `service_ports`, `ssh_public_key`, and
`rds_master_password`.

Outputs in [`outputs.tf`](outputs.tf) are read by the deployment workflow:
instance addresses for SSH deployment, and the ACM validation records and
API Gateway domain target for the GoDaddy DNS records.
