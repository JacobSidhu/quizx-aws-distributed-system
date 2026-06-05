# Cost Notes

QuizX AWS v1.0.0 is designed to keep AWS cost low while demonstrating EC2, Terraform, and Docker Compose.

## Cost-Aware Choices

- Uses one EC2 instance.
- Avoids NAT Gateway.
- Avoids Elastic Load Balancer.
- Avoids RDS for this version.
- Runs MySQL as a Docker container with a Docker volume.

## Cost Risks

- EC2 can generate cost while running.
- EBS storage can generate cost even after stopping the instance.
- Manually created Elastic IPs can generate cost if unattached.
- S3 remote Terraform state can have a small storage/request cost.

## Cleanup

After testing:

```bash
docker compose -f infra/docker/docker-compose.yml down
cd infra/terraform
terraform destroy
```

Then verify in AWS that EC2, security groups, subnets, route tables, internet gateway, VPC, and unused EBS resources are removed.
