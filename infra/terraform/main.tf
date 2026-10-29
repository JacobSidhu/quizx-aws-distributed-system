# ==============================================================================
# QuizX AWS infrastructure (root module)
# ==============================================================================
# Resources are grouped by concern, one file each:
#
#   versions.tf         Terraform and provider version constraints
#   providers.tf        AWS provider, assumed execution role, default tags
#   backend.tf          S3 remote state and the bootstrap remote state lookup
#   locals.tf           Naming prefix, standard tags, derived values
#   variables.tf        Input variables
#
#   vpc.tf              VPC, internet gateway, route tables, VPC endpoints
#   subnets.tf          Public and private subnets across two AZs
#   security-groups.tf  Security groups and the rules between them
#
#   ec2.tf              Question and submit app instances, SSH key pair
#   alb.tf              Internal ALB, target groups, path-based routing
#   api-gateway.tf      HTTP API, VPC link, and integration with the ALB
#   domain.tf           Optional custom domain (ACM + API Gateway mapping)
#
#   rds.tf              MySQL instance and its subnet group
#   sqs.tf              Application message queues
#   eks.tf              EKS cluster and managed node group
#   ecr.tf              Container image repository
#
#   outputs.tf          Values consumed by deployment workflows and operators
# ==============================================================================
