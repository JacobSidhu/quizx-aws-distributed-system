// -----------------------------------------------------------
// Virtual private cloud -------------------------------------
// -----------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.networking.vpc_cidr
  enable_dns_support   = var.networking.enable_dns_support
  enable_dns_hostnames = var.networking.enable_dns_hostnames

  tags = local.common_tags
}

// -----------------------------------------------------------
// API Gateway VPC link --------------------------------------
// -----------------------------------------------------------
resource "aws_apigatewayv2_vpc_link" "quizx_vpc_link" {
  name = "${local.name_prefix}-vpc-link"
  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
  security_group_ids = [aws_security_group.vpc_link_sg.id]
  tags               = local.common_tags
}

// -----------------------------------------------------------
// Internet gateway ------------------------------------------
// -----------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags
}

// -----------------------------------------------------------
// Public route table ----------------------------------------
// -----------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = local.common_tags

  route {
    cidr_block = var.public_route_config.cidr_block
    gateway_id = aws_internet_gateway.igw.id
  }
}

// -----------------------------------------------------------
// Public subnet route table associations --------------------
// -----------------------------------------------------------
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
