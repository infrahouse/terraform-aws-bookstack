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
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  apply_immediately         = true
  final_snapshot_identifier = "${var.service_name}-final-snapshot"
  parameter_group_name      = aws_db_parameter_group.mysql.name
  storage_encrypted         = true
  kms_key_id                = var.storage_encryption_key_arn
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  # CloudWatch Logs Export
  enabled_cloudwatch_logs_exports = var.enable_rds_cloudwatch_logs ? ["error", "general", "slowquery"] : []

  # Performance Insights
  # Automatically disabled for instance types that don't support it (see locals.tf)
  performance_insights_enabled          = local.performance_insights_enabled
  performance_insights_kms_key_id       = local.performance_insights_enabled ? var.storage_encryption_key_arn : null
  performance_insights_retention_period = local.performance_insights_enabled ? var.rds_performance_insights_retention_days : null

  tags = merge(
    local.tags,
    {
      module_version : local.module_version
    }
  )
  depends_on = [
    aws_cloudwatch_log_group.rds_error,
    aws_cloudwatch_log_group.rds_general,
    aws_cloudwatch_log_group.rds_slowquery
  ]
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
