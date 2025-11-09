locals {
  module_version = "3.1.0"

  db_identifier = var.db_identifier != null ? var.db_identifier : "${var.service_name}-encrypted"
  tags = {
    created_by_module : "infrahouse/bookstack/aws"
  }
  smtp_endpoints = {
    us-west-1 : "email-smtp.us-west-1.amazonaws.com"
    us-west-2 : "email-smtp.us-west-2.amazonaws.com"
    us-east-1 : "email-smtp.us-east-1.amazonaws.com"
    us-east-2 : "email-smtp.us-east-2.amazonaws.com"
  }
  dns_a_records = var.dns_a_records == null ? [var.service_name] : var.dns_a_records
  ec2_role_name = "${var.service_name}-${random_string.role-suffix.result}"
  ec2_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.ec2_role_name}"
  db_params_common = [
    {
      apply_method = "immediate"
      name         = "binlog_format"
      value        = "ROW"
    },
  ]
  ami_name_pattern_pro = "ubuntu-pro-server/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-*"

  # RDS instance types that do NOT support Performance Insights for MySQL
  # Reference: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.Overview.Engines.html
  # Keeping a blocklist is safer than allowlist - new instance types typically support PI
  rds_performance_insights_unsupported_types = [
    # AWS officially lists these instance classes as unsupported for RDS MySQL Performance Insights:
    "db.t2.micro",
    "db.t2.small",
    "db.t3.micro",
    "db.t3.small",
    "db.t4g.micro",
    "db.t4g.small",
  ]

  # Auto-disable Performance Insights for unsupported instance types
  # Users can still explicitly set enable_rds_performance_insights=false for any instance type
  performance_insights_enabled = var.enable_rds_performance_insights && !contains(
    local.rds_performance_insights_unsupported_types,
    var.db_instance_type
  )
}
