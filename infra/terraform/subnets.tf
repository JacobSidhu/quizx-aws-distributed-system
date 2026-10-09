// -----------------------------------------------------------
// Creates Public Subnet 1 for VPC ---------------------------
// -----------------------------------------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.public_subnet_cidrs[0]
  availability_zone       = var.networking.availability_zones[0]
  map_public_ip_on_launch = false

  tags = local.common_tags
}
// -----------------------------------------------------------
// Creates Public Subnet 2 for VPC ---------------------------
// -----------------------------------------------------------
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.public_subnet_cidrs[1]
  availability_zone       = var.networking.availability_zones[1]
  map_public_ip_on_launch = false
  tags                    = local.common_tags
}
// -----------------------------------------------------------
// Creates Private Subnet 1 for VPC --------------------------
// -----------------------------------------------------------
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.private_subnet_cidrs[0]
  availability_zone       = var.networking.availability_zones[0]
  map_public_ip_on_launch = false

  tags = local.common_tags
}
// -----------------------------------------------------------
// Creates Private Subnet 2 for VPC --------------------------
// -----------------------------------------------------------
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.networking.private_subnet_cidrs[1]
  availability_zone       = var.networking.availability_zones[1]
  map_public_ip_on_launch = false

  tags = local.common_tags
}
// -----------------------------------------------------------
// --------------- RDS Subnet Group --------------------------
// -----------------------------------------------------------
resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags       = local.common_tags
}