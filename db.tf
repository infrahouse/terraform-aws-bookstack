resource "aws_db_instance" "db" {
  instance_class          = var.db_instance_type
  identifier_prefix       = var.service_name
  allocated_storage       = 10
  max_allocated_storage   = 100
  db_name                 = var.service_name
  engine                  = "mysql"
  engine_version          = "8.0"
  username                = "${var.service_name}_user"
  password                = random_password.db_user.result
  db_subnet_group_name    = aws_db_subnet_group.db.name
  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]
}


resource "aws_db_subnet_group" "db" {
  name_prefix = var.service_name
  subnet_ids  = var.backend_subnet_ids
}


resource "random_password" "db_user" {
  length  = 21
  special = false
}

