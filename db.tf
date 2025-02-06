resource "aws_db_instance" "db" {
  instance_class            = var.db_instance_type
  identifier_prefix         = "${var.service_name}-encrypted"
  allocated_storage         = 10
  max_allocated_storage     = 100
  db_name                   = var.service_name
  engine                    = "mysql"
  engine_version            = "8.0"
  username                  = "${var.service_name}_user"
  password                  = random_password.db_user.result
  db_subnet_group_name      = aws_db_subnet_group.db.name
  multi_az                  = true
  backup_retention_period   = 7
  deletion_protection       = false
  skip_final_snapshot       = false
  apply_immediately         = true
  final_snapshot_identifier = "${var.service_name}-final-snapshot"
  parameter_group_name      = aws_db_parameter_group.mysql.name
  storage_encrypted         = var.storage_encryption_key_arn != null ? true : false
  kms_key_id                = var.storage_encryption_key_arn
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]
  tags = local.tags
}

resource "aws_db_subnet_group" "db" {
  name_prefix = var.service_name
  subnet_ids  = var.backend_subnet_ids
  tags        = local.tags
}


resource "random_password" "db_user" {
  length  = 21
  special = false
}

resource "aws_db_parameter_group" "mysql" {
  name_prefix = "${var.service_name}-"
  family      = "mysql8.0"
  dynamic "parameter" {
    for_each = toset(
      concat(
        local.db_params_common,
      )
    )
    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }
}
