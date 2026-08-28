# Cost Notes

QuizX AWS v2.0.0 is designed to keep AWS cost controlled while demonstrating distributed EC2 workloads, RabbitMQ, Terraform, and Docker Compose.

## Cost-Aware Choices

- Uses two small EC2 instances instead of managed container orchestration.
- Avoids NAT Gateway.
- Avoids Elastic Load Balancer.
- Avoids RDS for this version.
- Runs MySQL as a Docker container with a Docker volume.
- Runs RabbitMQ as a Docker container instead of using Amazon MQ.

## Cost Risks

- Both EC2 instances and their EBS volumes can generate cost while running.
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
