# ==============================================================================
# VPC and routing
# ==============================================================================
# One VPC with public and private subnets in two availability zones (see
# subnets.tf):
#
#   Public subnets   Routed to the internet gateway. Host the EC2 application
#                    servers, the internal ALB, and the API Gateway VPC link.
#   Private subnets  No internet route and no NAT gateway. Host RDS and the EKS
#                    nodes, which reach AWS APIs only through the VPC endpoints
#                    defined below.
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.networking.vpc_cidr
  enable_dns_support   = var.networking.enable_dns_support
  enable_dns_hostnames = var.networking.enable_dns_hostnames

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Public routing
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags

  route {
    cidr_block = var.public_route_config.cidr_block
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# Private routing
# ------------------------------------------------------------------------------
# Local VPC traffic only. The S3 gateway endpoint adds its own route to this
# table.
# ------------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------------------------------------------------------
# VPC endpoints
# ------------------------------------------------------------------------------
# Give the private subnets access to the AWS services EKS nodes need to join
# the cluster and pull images, without internet access:
#   EC2      node bootstrap and networking (VPC CNI)
#   ECR API  registry authentication and metadata
#   ECR DKR  image pulls
#   S3       image layers (ECR stores them in S3)
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "endpoint" {
  for_each = {
    EC2     = "com.amazonaws.${var.aws_region}.ec2"
    ECR_DKR = "com.amazonaws.${var.aws_region}.ecr.dkr"
    ECR_API = "com.amazonaws.${var.aws_region}.ecr.api"
  }

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags                = local.common_tags
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids   = [aws_route_table.private.id]
  vpc_endpoint_type = "Gateway"
  tags              = local.common_tags
}
