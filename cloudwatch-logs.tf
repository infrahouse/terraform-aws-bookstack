# CloudWatch Log Groups for RDS
# These log groups are created to set retention policies for RDS CloudWatch logs
# RDS automatically publishes to these log groups when enabled_cloudwatch_logs_exports is set

resource "aws_cloudwatch_log_group" "rds_error" {
  count = var.enable_rds_cloudwatch_logs ? 1 : 0

  name              = "/aws/rds/instance/${local.db_identifier}/error"
  retention_in_days = var.rds_cloudwatch_logs_retention_days

  tags = merge(
    {
      Name = "${var.service_name}-rds-error-logs"
    },
    local.tags
  )
}

resource "aws_cloudwatch_log_group" "rds_general" {
  count = var.enable_rds_cloudwatch_logs ? 1 : 0

  name              = "/aws/rds/instance/${local.db_identifier}/general"
  retention_in_days = var.rds_cloudwatch_logs_retention_days

  tags = merge(
    {
      Name = "${var.service_name}-rds-general-logs"
    },
    local.tags
  )
}

resource "aws_cloudwatch_log_group" "rds_slowquery" {
  count = var.enable_rds_cloudwatch_logs ? 1 : 0

  name              = "/aws/rds/instance/${local.db_identifier}/slowquery"
  retention_in_days = var.rds_cloudwatch_logs_retention_days

  tags = merge(
    {
      Name = "${var.service_name}-rds-slowquery-logs"
    },
    local.tags
  )
}