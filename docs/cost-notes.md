# Cost Notes

QuizX AWS v3.0.0 is designed for short-lived learning deployments. Version 3
adds an Application Load Balancer, API Gateway, VPC Link, ACM, and public IPv4
addresses to the two-instance v2 runtime, so prompt cleanup is important.

## Cost-Generating Resources

- Two EC2 instances and their EBS root volumes
- Public IPv4 addresses attached to the EC2 instances
- Internal Application Load Balancer capacity and running hours
- API Gateway requests and related data transfer
- S3 storage and requests for the Terraform backend
- Data transfer and any AWS service logs generated during testing
- GoDaddy domain registration, which exists outside Terraform

AWS pricing changes over time and varies by region. Check the current AWS
pricing pages and account billing dashboard before each deployment.

## Cost-Aware Choices

- Uses small EC2 instance types for a demonstration workload.
- Uses Docker Compose instead of ECS or EKS.
- Avoids NAT Gateway by placing the learning instances in public subnets.
- Runs MySQL in Docker instead of Amazon RDS.
- Runs RabbitMQ in Docker instead of Amazon MQ.
- Does not require ECR because deployment builds images on each instance.
- Uses an internal ALB only for the API Gateway private integration.
- Destroys the application infrastructure after validation.

## Cleanup Procedure

Use the GitHub Actions **Deploy** workflow with:

```text
terraform_action: destroy
allowed_ssh_cidr: YOUR_PUBLIC_IPV4/32
```

The workflow removes matching GoDaddy certificate-validation and application
CNAME records before Terraform destroys the API Gateway, VPC Link, ALB, ACM
certificate, EC2 instances, security groups, subnets, routing resources, and
VPC.

The S3 backend and GoDaddy domain are intentionally outside the application
destroy lifecycle. They must be reviewed separately if they are no longer
needed.

## Post-Cleanup Checks

Confirm that no unexpected resources remain:

- running or stopped EC2 instances;
- unattached EBS volumes or snapshots;
- billable public IPv4 or Elastic IP allocations;
- Application Load Balancers or target groups;
- API Gateway APIs, custom domains, or VPC Links;
- ACM certificates created for the test deployment;
- VPC networking resources blocked from deletion by dependencies;
- stale GoDaddy DNS records.

Review AWS Billing and Cost Explorer after each demonstration. Billing data can
lag behind resource deletion, so a successful destroy does not immediately
guarantee a zero current-period total.
