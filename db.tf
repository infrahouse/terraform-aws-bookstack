module "rds" {
  source  = "registry.infrahouse.com/infrahouse/rds/aws"
  version = "0.2.2"

  environment  = var.environment
  service_name = var.service_name
  subnet_ids   = var.backend_subnet_ids

  # Preserve current behavior: reachable from anywhere in the VPC.
  allowed_cidrs = [data.aws_vpc.selected.cidr_block]

  instance_class        = var.db_instance_type
  engine_version        = "8.4"
  db_name               = var.service_name
  username              = "${var.service_name}_user"
  multi_az              = true
  allocated_storage     = 20 # gp3 minimum for MySQL
  max_allocated_storage = 100
  deletion_protection   = var.deletion_protection
  skip_final_snapshot   = var.skip_final_snapshot
  kms_key_id            = var.storage_encryption_key_arn

  # ROW is the default (and only forward-looking) binlog_format in MySQL 8.4,
  # so no parameter overrides are needed.
  parameter_group_family = "mysql8.4"

  performance_insights_retention_period = var.rds_performance_insights_retention_days

  # The module manages CloudWatch alarms, SNS, and email subscriptions.
  alarm_emails = var.alarm_emails

  # Let the EC2 instance role read the AWS-managed master password secret.
  secret_readers = [
    local.ec2_role_arn
  ]

  tags = local.tags
}

# Resolve the name of the module's AWS-managed master password secret so it can be
# passed to the application (Puppet reads the secret by name).
data "aws_secretsmanager_secret" "master" {
  arn = module.rds.master_secret_arn
}
