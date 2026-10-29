# ==============================================================================
# RDS (MySQL)
# ==============================================================================
# Single-AZ MySQL instance in the private subnets, reachable only from the
# question app security group (see security-groups.tf).
#
# Development settings: storage is not encrypted, there is no deletion
# protection, backups are kept for one day, and no final snapshot is taken on
# destroy. Review these before using this stack for production.
# ==============================================================================
resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-rds-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags       = local.common_tags
}

resource "aws_db_instance" "quizx_rds" {
  identifier        = "${local.name_prefix}-rds-mysql"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = false

  db_name  = "quizxdevmysqldbinstance"
  username = "quizxadmin"
  password = var.rds_master_password

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  multi_az               = false

  skip_final_snapshot     = true
  backup_retention_period = 1
  deletion_protection     = false
  tags                    = local.common_tags
}
