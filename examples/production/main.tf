# Production Example
# BookStack in an existing VPC with customer-managed encryption keys, a larger
# instance fleet, several DNS names and alarms routed to PagerDuty.

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# The Route 53 zone lives in a dedicated DNS account. The module creates the
# BookStack records with this provider.
provider "aws" {
  alias  = "dns"
  region = var.region

  assume_role {
    role_arn = var.dns_role_arn
  }
}

data "aws_route53_zone" "current" {
  provider = aws.dns

  zone_id = var.zone_id
}

# Customer-managed keys let you audit and revoke access to the data at rest
# independently of AWS-managed keys.
resource "aws_kms_key" "rds" {
  # checkov:skip=CKV2_AWS_64: the default key policy (account root administers the
  # key through IAM) is intended here. Replace it with an explicit policy that
  # names your key administrators and users when you adopt this example.
  description             = "BookStack RDS storage encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds" {
  name          = "alias/bookstack-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "efs" {
  # checkov:skip=CKV2_AWS_64: see the note on aws_kms_key.rds above.
  description             = "BookStack EFS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "efs" {
  name          = "alias/bookstack-efs"
  target_key_id = aws_kms_key.efs.key_id
}

module "google_client" {
  source  = "registry.infrahouse.com/infrahouse/secret/aws"
  version = "1.3.0"

  environment        = "production"
  service_name       = "bookstack"
  secret_name_prefix = "bookstack_google_client"
  secret_description = "Google OAuth client id and secret for BookStack"
  secret_value       = var.google_oauth_client_json
  readers = [
    module.bookstack.bookstack_instance_role_arn
  ]
}

module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "4.2.0"
  providers = {
    aws     = aws
    aws.dns = aws.dns
  }

  environment                   = "production"
  service_name                  = "bookstack"
  lb_subnet_ids                 = var.lb_subnet_ids
  backend_subnet_ids            = var.backend_subnet_ids
  zone_id                       = var.zone_id
  access_log_replication_region = var.access_log_replication_region

  # Serve the same wiki under several names: bookstack.example.com,
  # wiki.example.com and docs.example.com.
  dns_a_records = ["bookstack", "wiki", "docs"]

  # Three instances across three AZs, scaling up to six.
  instance_type    = "t3.medium"
  asg_min_size     = 3
  asg_max_size     = 6
  db_instance_type = "db.m6g.large"

  # Encryption with customer-managed keys instead of the AWS-managed defaults.
  storage_encryption_key_arn = aws_kms_key.rds.arn
  efs_encryption_key_arn     = aws_kms_key.efs.arn

  google_oauth_client_secret = module.google_client.secret_name

  # Rotate the SES SMTP credentials monthly instead of every 45 days.
  smtp_key_rotation_days = 30

  # Alarms go to the on-call inbox and to PagerDuty.
  alarm_emails     = var.alarm_emails
  alarm_topic_arns = [var.pagerduty_topic_arn]

  # Alert earlier than the module defaults on sender reputation.
  ses_bounce_rate_threshold    = 0.03   # 3% instead of 5%
  ses_complaint_rate_threshold = 0.0005 # 0.05% instead of 0.1%

  # Two years of Performance Insights history (billed separately).
  rds_performance_insights_retention_days = 731

  # Protect the database from accidental removal.
  deletion_protection = true
  skip_final_snapshot = false

  # Extra packages push the userdata towards the 16KB EC2 limit, so compress it.
  packages          = ["awscli"]
  compress_userdata = true
}

output "bookstack_urls" {
  description = "URLs where BookStack is available"
  value       = module.bookstack.bookstack_urls
}

output "bookstack_zone_name" {
  description = "Route 53 zone the BookStack records are created in"
  value       = data.aws_route53_zone.current.name
}

output "smtp_credentials_next_rotation" {
  description = "When the SES SMTP credentials are rotated next"
  value       = module.bookstack.smtp_credentials_next_rotation
}

output "sns_topic_arn" {
  description = "SNS topic the module publishes alarms to"
  value       = module.bookstack.sns_topic_arn
}
