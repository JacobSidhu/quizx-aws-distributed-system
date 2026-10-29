# ==============================================================================
# Subnets
# ==============================================================================
# Two public and two private subnets, one of each per availability zone.
# CIDRs and zones come from var.networking. No subnet assigns public IPs
# automatically; the EC2 instances request one explicitly (see ec2.tf).
# ==============================================================================

# ------------------------------------------------------------------------------
# Public subnets (routed to the internet gateway)
# ------------------------------------------------------------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.public_subnet_cidrs[0]
  availability_zone       = var.networking.availability_zones[0]
  map_public_ip_on_launch = false

  tags = local.common_tags
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.public_subnet_cidrs[1]
  availability_zone       = var.networking.availability_zones[1]
  map_public_ip_on_launch = false

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Private subnets (no internet route; RDS, EKS, and VPC endpoints)
# ------------------------------------------------------------------------------
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.private_subnet_cidrs[0]
  availability_zone       = var.networking.availability_zones[0]
  map_public_ip_on_launch = false

  tags = local.common_tags
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.private_subnet_cidrs[1]
  availability_zone       = var.networking.availability_zones[1]
  map_public_ip_on_launch = false

  tags = local.common_tags
}
