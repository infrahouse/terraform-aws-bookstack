# terraform-aws-bookstack

[![InfraHouse](https://img.shields.io/badge/InfraHouse-Terraform_Module-blue?logo=terraform)](https://registry.terraform.io/modules/infrahouse/bookstack/aws/latest)
[![License](https://img.shields.io/github/license/infrahouse/terraform-aws-bookstack)](LICENSE)
[![CI](https://github.com/infrahouse/terraform-aws-bookstack/actions/workflows/terraform-CI.yml/badge.svg)](https://github.com/infrahouse/terraform-aws-bookstack/actions/workflows/terraform-CI.yml)
[![BookStack](https://img.shields.io/badge/BookStack-Documentation-blue?logo=bookstack)](https://www.bookstackapp.com/)

Terraform module to deploy [BookStack](https://www.bookstackapp.com/) on AWS with enterprise-grade security and monitoring.

## Overview

This module deploys a highly available BookStack installation on AWS with:
- Auto-scaling EC2 instances managed by an Application Load Balancer
- Multi-AZ RDS MySQL database with automated backups
- Encrypted EFS for shared file storage (uploads, images)
- SES integration for email notifications with automatic IAM key rotation
- CloudWatch alarms for SES reputation and RDS metrics
- Google OAuth authentication support
- Full encryption at rest for all data stores

## Features

### Security
- **Encryption by Default**: RDS and EFS are always encrypted (AWS managed keys by default, custom KMS keys supported)
- **IAM Key Rotation**: Automatic rotation of SES SMTP credentials every 45 days (configurable 30-90 days)
- **Least Privilege IAM**: SES permissions restricted to sending from verified domain only
- **Secrets Management**: All credentials stored in AWS Secrets Manager with automatic rotation support
- **Network Isolation**: Database and EFS restricted to VPC traffic only

### Monitoring & Alerting
- **Email Notifications**: SNS topic with email subscriptions for all alarms
- **SES Reputation Monitoring**: CloudWatch alarms for bounce rate (5%) and complaint rate (0.1%)
- **RDS Health Monitoring**: Alarms for CPU utilization, storage space, and connection count (all thresholds configurable)
- **RDS CloudWatch Logs**: Error, general, and slow query logs exported to CloudWatch (365-day retention by default)
- **Performance Insights**: Advanced RDS performance monitoring enabled by default (7-day free tier retention)
- **Integration Ready**: Support for external SNS topics (PagerDuty, Slack, etc.)

### High Availability
- **Multi-AZ Database**: RDS instance with automated backups and snapshots
- **Auto-Scaling**: EC2 instances distributed across availability zones
- **Load Balancing**: Application Load Balancer with health checks
- **Shared Storage**: EFS for consistent file storage across instances

### Infrastructure as Code
- **AWS Provider Compatibility**: Supports both AWS provider v5 and v6
- **Terraform 1.5+**: Modern Terraform version support
- **InfraHouse Standards**: Follows InfraHouse module conventions and patterns

## Architecture

```
                                   ┌─────────────────┐
                                   │   Route 53      │
                                   │  DNS Records    │
                                   └────────┬────────┘
                                            │
                                   ┌────────▼────────┐
                                   │  Application    │
                                   │ Load Balancer   │
                                   └────────┬────────┘
                                            │
                        ┌───────────────────┼───────────────────┐
                        │                   │                   │
                ┌───────▼────────┐ ┌────────▼───────┐ ┌─────────▼──────┐
                │   BookStack    │ │   BookStack    │ │   BookStack    │
                │   EC2 (AZ-A)   │ │   EC2 (AZ-B)   │ │   EC2 (AZ-C)   │
                └───────┬────────┘ └────────┬───────┘ └─────────┬──────┘
                        │                   │                   │
                        └───────────────────┼───────────────────┘
                                            │
                        ┌───────────────────┼──────────────────┐
                        │                   │                  │
                ┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
                │   RDS MySQL    │  │   EFS Shared   │  │  AWS Secrets   │
                │   (Multi-AZ)   │  │    Storage     │  │    Manager     │
                │   (Encrypted)  │  │  (Encrypted)   │  │                │
                └────────────────┘  └────────────────┘  └────────────────┘

                ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
                │   Amazon SES   │  │   SNS Topic    │  │   CloudWatch   │
                │ (Email Sending)│  │ (Alert Emails) │  │    Alarms      │
                └────────────────┘  └────────────────┘  └────────────────┘
```

## Usage

### Basic Example

```hcl
module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "3.0.0"

  # Network Configuration
  backend_subnet_ids = ["subnet-abc123", "subnet-def456"]
  lb_subnet_ids      = ["subnet-public1", "subnet-public2"]
  internet_gateway_id = "igw-xyz789"

  # DNS Configuration
  zone_id = "Z1234567890ABC"
  service_name = "wiki"  # Will be accessible at wiki.yourdomain.com

  # Required Secrets
  google_oauth_client_secret = "google-oauth-bookstack"  # AWS Secrets Manager secret name

  # Monitoring (REQUIRED)
  alarm_emails = [
    "ops-team@example.com",
    "devops@example.com"
  ]

  providers = {
    aws     = aws
    aws.dns = aws  # Can be different account for DNS
  }
}
```

### Advanced Example with Custom Encryption Keys

```hcl
module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "3.0.0"

  # Network Configuration
  backend_subnet_ids = ["subnet-abc123", "subnet-def456", "subnet-ghi789"]
  lb_subnet_ids      = ["subnet-public1", "subnet-public2", "subnet-public3"]
  internet_gateway_id = "igw-xyz789"

  # DNS Configuration
  zone_id       = "Z1234567890ABC"
  service_name  = "docs"
  dns_a_records = ["docs", "wiki", "knowledge"]  # Multiple DNS names

  # Instance Configuration
  instance_type     = "t3.small"
  db_instance_type  = "db.t3.small"
  asg_min_size      = 2
  asg_max_size      = 6

  # Encryption with Custom KMS Keys
  storage_encryption_key_arn = aws_kms_key.rds.arn
  efs_encryption_key_arn     = aws_kms_key.efs.arn

  # SMTP Key Rotation
  smtp_key_rotation_days = 30  # Rotate every 30 days

  # Monitoring Configuration
  alarm_emails = ["ops-team@example.com"]
  alarm_topic_arns = [
    "arn:aws:sns:us-east-1:123456789012:pagerduty-critical"
  ]

  # Custom Alarm Thresholds
  ses_bounce_rate_threshold    = 0.03   # 3% instead of default 5%
  ses_complaint_rate_threshold = 0.0005 # 0.05% instead of default 0.1%
  rds_cpu_threshold            = 70     # 70% instead of default 80%
  rds_storage_threshold_gb     = 10     # 10GB instead of default 5GB
  rds_connections_threshold    = 100    # 100 connections instead of default 80

  # RDS Monitoring Configuration
  enable_rds_cloudwatch_logs              = true
  rds_cloudwatch_logs_retention_days      = 731  # 2 years instead of default 1 year
  enable_rds_performance_insights         = true
  rds_performance_insights_retention_days = 731  # 2 years (additional cost) instead of 7-day free tier

  # Google OAuth
  google_oauth_client_secret = "google-oauth-bookstack"

  # Database Configuration
  deletion_protection  = true
  skip_final_snapshot = false

  providers = {
    aws     = aws.main
    aws.dns = aws.dns_account  # Separate account for DNS
  }
}
```

## Important Notes

### Breaking Changes in v3.0

1. **`alarm_emails` is now REQUIRED**: You must provide at least one email address for alarm notifications
2. **Encryption Always Enabled**: RDS and EFS encryption is now mandatory (was optional in v2.x)
3. **EFS Data Migration**: Upgrading from v2.x will recreate the EFS filesystem - **backup your data first!**
4. **⚠️ RDS Identifier Change**: The module now uses fixed `identifier` instead of `identifier_prefix` to prevent CloudWatch log group race conditions. **Requires Terraform state manipulation to avoid database recreation** - see migration instructions below.

### Upgrading from v2.x

#### RDS Identifier Migration (CRITICAL - Do this first!)

The module now uses a fixed `identifier` instead of `identifier_prefix`. To avoid recreating your RDS instance:

```bash
# 1. Get your current RDS identifier from Terraform state
terraform state show 'module.bookstack.aws_db_instance.db' | grep '^\s*identifier\s*='
# Example output: identifier = "bookstack-encrypted20251109012345678900000001"

# 2. Add the exact identifier to your Terraform code
# In your module block, add:
# db_identifier = "bookstack-encrypted20251109012345678900000001"  # Use YOUR actual identifier

# 3. Run terraform plan to verify - should show no changes to RDS instance
terraform plan

# If plan shows RDS will be recreated, DO NOT APPLY. Double-check the identifier matches exactly.
# The plan should show "No changes" for the RDS instance.

# IMPORTANT: Once you set db_identifier for an existing installation, it is PERMANENT.
# Removing it later will cause Terraform to recreate your database!
# New installations should NOT set db_identifier - they will use the clean default.
```

#### EFS Migration (if upgrading from unencrypted EFS)

If you're upgrading from v2.x and have an existing unencrypted EFS:

```bash
# 1. Backup EFS data
aws efs describe-file-systems --file-system-id fs-xxxxx
# Mount and backup: rsync -av /mnt/efs/ /backup/bookstack-uploads/

# 2. Update module version
# In your terraform code, update to version ~> 3.0

# 3. Apply (will recreate EFS)
terraform apply

# 4. Restore data
# Mount new EFS and restore: rsync -av /backup/bookstack-uploads/ /mnt/efs/
```

### SMTP Credentials and Key Rotation

The module automatically creates and rotates SES SMTP credentials:

- **Rotation Schedule**: Every 45 days by default (configurable 30-90 days)
- **Zero Downtime**: New key created before old key deleted
- **Automatic Restart**: Puppet automatically restarts services when credentials rotate
- **Manual Trigger**: Run `terraform apply` to trigger rotation on schedule

Monitor rotation status via outputs:
```hcl
output "next_rotation" {
  value = module.bookstack.smtp_credentials_next_rotation
}

output "last_rotated" {
  value = module.bookstack.smtp_credentials_last_rotated
}
```

### Security Considerations

1. **SES Sending Limits**: Ensure your AWS account is out of SES sandbox mode
2. **DNS Verification**: Verify your domain in SES before deployment
3. **Google OAuth Setup**: Configure OAuth credentials in Google Cloud Console
4. **Secrets Manager**: Store Google OAuth credentials in AWS Secrets Manager
5. **VPC Configuration**: Ensure proper VPC, subnet, and internet gateway setup
6. ⚠️ **TLS Private Key in Terraform State**: This module generates SSH keys using `tls_private_key` resource. The private key will be stored in Terraform state. Ensure your state backend is encrypted and access-controlled (e.g., S3 with encryption and restrictive IAM policies). For enhanced security, consider generating SSH keys externally and passing them via `key_pair_name` variable instead.

### Cost Optimization Tips

- Use `t3.micro` instances for development environments
- Set `deletion_protection = false` and `skip_final_snapshot = true` for non-production
- Use AWS managed KMS keys (default) instead of custom keys for lower costs
- Configure appropriate `asg_min_size` and `asg_max_size` for your workload

## Outputs

The module provides several useful outputs:

```hcl
# BookStack URLs
module.bookstack.bookstack_urls  # ["https://wiki.example.com"]

# Infrastructure ARNs
module.bookstack.bookstack_load_balancer_arn
module.bookstack.bookstack_instance_role_arn
module.bookstack.rds_instance_identifier

# Monitoring
module.bookstack.sns_topic_arn
module.bookstack.smtp_credentials_next_rotation
module.bookstack.smtp_credentials_last_rotated
```

## Requirements

- **Terraform**: ~> 1.5
- **AWS Provider**: >= 5.11, < 7.0
- **AWS Account**: With SES verified domain
- **VPC**: With public and private subnets
- **Route53**: Hosted zone for your domain

## Contributing

Contributions are welcome! Please:
1. Open an issue to discuss proposed changes
2. Follow InfraHouse Terraform module standards
3. Include tests for new features
4. Update documentation

## License

Apache 2.0 Licensed. See LICENSE for full details.

## Support

- **Issues**: https://github.com/infrahouse/terraform-aws-bookstack/issues
- **InfraHouse**: https://infrahouse.com

---

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.11, < 7.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.13 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.11, < 7.0 |
| <a name="provider_aws.dns"></a> [aws.dns](#provider\_aws.dns) | >= 5.11, < 7.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.13 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~> 4.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_bookstack"></a> [bookstack](#module\_bookstack) | registry.infrahouse.com/infrahouse/website-pod/aws | 5.8.2 |
| <a name="module_bookstack-userdata"></a> [bookstack-userdata](#module\_bookstack-userdata) | registry.infrahouse.com/infrahouse/cloud-init/aws | 2.2.2 |
| <a name="module_bookstack_app_key"></a> [bookstack\_app\_key](#module\_bookstack\_app\_key) | registry.infrahouse.com/infrahouse/secret/aws | 1.1.0 |
| <a name="module_db_user"></a> [db\_user](#module\_db\_user) | registry.infrahouse.com/infrahouse/secret/aws | 1.1.0 |
| <a name="module_ses_smtp_password"></a> [ses\_smtp\_password](#module\_ses\_smtp\_password) | registry.infrahouse.com/infrahouse/secret/aws | 1.1.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.rds_error](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.rds_general](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.rds_slowquery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.rds_connections](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.rds_storage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ses_bounce_rate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ses_complaint_rate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_db_instance.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.mysql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_efs_file_system.bookstack-uploads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.bookstack-uploads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_iam_access_key.emailer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_policy.emailer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_user.emailer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.emailer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_key_pair.deployer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_security_group.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_sns_topic.alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.alarm_emails](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_vpc_security_group_egress_rule.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.efs_icmp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.mysql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.bookstack_app_key](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.db_user](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.role-suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [time_rotating.key_rotation](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |
| [tls_private_key.rsa](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [aws_ami.ubuntu_pro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.emailer_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.instance_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_secretsmanager_secret.google_client](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_ses_domain_identity.zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ses_domain_identity) | data source |
| [aws_subnet.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_log_force_destroy"></a> [access\_log\_force\_destroy](#input\_access\_log\_force\_destroy) | Destroy S3 bucket with access logs even if non-empty | `bool` | `false` | no |
| <a name="input_alarm_emails"></a> [alarm\_emails](#input\_alarm\_emails) | List of email addresses to receive alarm notifications for SES bounce rate, RDS issues, etc.<br/>AWS will send confirmation emails that must be accepted.<br/>At least one email is required. | `list(string)` | n/a | yes |
| <a name="input_alarm_topic_arns"></a> [alarm\_topic\_arns](#input\_alarm\_topic\_arns) | List of existing SNS topic ARNs to send alarms to.<br/>Use for advanced integrations like PagerDuty, Slack, etc. | `list(string)` | `[]` | no |
| <a name="input_asg_ami"></a> [asg\_ami](#input\_asg\_ami) | Image for EC2 instances | `string` | `null` | no |
| <a name="input_asg_health_check_grace_period"></a> [asg\_health\_check\_grace\_period](#input\_asg\_health\_check\_grace\_period) | ASG will wait up to this number of minutes for instance to become healthy | `number` | `600` | no |
| <a name="input_asg_max_size"></a> [asg\_max\_size](#input\_asg\_max\_size) | Maximum number of instances in ASG | `number` | `null` | no |
| <a name="input_asg_min_size"></a> [asg\_min\_size](#input\_asg\_min\_size) | Minimum number of instances in ASG | `number` | `null` | no |
| <a name="input_backend_subnet_ids"></a> [backend\_subnet\_ids](#input\_backend\_subnet\_ids) | List of subnet ids where the webserver and database instances will be created | `list(string)` | n/a | yes |
| <a name="input_db_identifier"></a> [db\_identifier](#input\_db\_identifier) | RDS instance identifier. If not provided, defaults to var.service\_name-encrypted.<br/><br/>MIGRATION ONLY: Set this to your existing RDS identifier when upgrading from v2.x.<br/>Once set, this value is PERMANENT - removing it will cause database recreation.<br/><br/>New installations should NOT set this variable - use the default instead. | `string` | `null` | no |
| <a name="input_db_instance_type"></a> [db\_instance\_type](#input\_db\_instance\_type) | Instance type to run the database instances | `string` | `"db.t3.micro"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Specifies whether to enable deletion protection for the DB instance. | `bool` | `true` | no |
| <a name="input_dns_a_records"></a> [dns\_a\_records](#input\_dns\_a\_records) | A list of A records the BookStack application will be accessible at.<br/>E.g. ["wiki"] or ["bookstack", "docs"].<br/>By default, it will be [var.service\_name]. | `list(string)` | `null` | no |
| <a name="input_efs_encryption_key_arn"></a> [efs\_encryption\_key\_arn](#input\_efs\_encryption\_key\_arn) | KMS key ARN to encrypt EFS file system.<br/>If not provided, AWS managed key will be used.<br/>EFS encryption is always enabled. | `string` | `null` | no |
| <a name="input_enable_rds_alarms"></a> [enable\_rds\_alarms](#input\_enable\_rds\_alarms) | Enable CloudWatch alarms for RDS metrics | `bool` | `true` | no |
| <a name="input_enable_rds_cloudwatch_logs"></a> [enable\_rds\_cloudwatch\_logs](#input\_enable\_rds\_cloudwatch\_logs) | Enable CloudWatch logs export for RDS.<br/>Exports error, general, and slow query logs to CloudWatch. | `bool` | `true` | no |
| <a name="input_enable_rds_performance_insights"></a> [enable\_rds\_performance\_insights](#input\_enable\_rds\_performance\_insights) | Enable Performance Insights for RDS.<br/>Provides advanced database performance monitoring and analysis. | `bool` | `true` | no |
| <a name="input_enable_ses_alarms"></a> [enable\_ses\_alarms](#input\_enable\_ses\_alarms) | Enable CloudWatch alarms for SES bounce/complaint rates | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Name of environment. | `string` | `"development"` | no |
| <a name="input_extra_files"></a> [extra\_files](#input\_extra\_files) | Additional files to create on an instance. | <pre>list(<br/>    object(<br/>      {<br/>        content     = string<br/>        path        = string<br/>        permissions = string<br/>      }<br/>    )<br/>  )</pre> | `[]` | no |
| <a name="input_extra_instance_profile_permissions"></a> [extra\_instance\_profile\_permissions](#input\_extra\_instance\_profile\_permissions) | A JSON with a permissions policy document.<br/>The policy will be attached to the ASG instance profile. | `string` | `null` | no |
| <a name="input_extra_repos"></a> [extra\_repos](#input\_extra\_repos) | Additional APT repositories to configure on an instance. | <pre>map(<br/>    object(<br/>      {<br/>        source = string<br/>        key    = string<br/>      }<br/>    )<br/>  )</pre> | `{}` | no |
| <a name="input_google_oauth_client_secret"></a> [google\_oauth\_client\_secret](#input\_google\_oauth\_client\_secret) | AWS secretsmanager secret name with a Google Oauth 'client id' and 'client secret'. | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Instance type to run the webserver instances | `string` | `"t3.micro"` | no |
| <a name="input_internet_gateway_id"></a> [internet\_gateway\_id](#input\_internet\_gateway\_id) | Not used, but AWS Internet Gateway must be present. Ensure by passing its id. | `string` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | SSH keypair name to be deployed in EC2 instances | `string` | `null` | no |
| <a name="input_lb_subnet_ids"></a> [lb\_subnet\_ids](#input\_lb\_subnet\_ids) | List of subnet ids where the load balancer will be created | `list(string)` | n/a | yes |
| <a name="input_packages"></a> [packages](#input\_packages) | List of packages to install when the instances bootstraps. | `list(string)` | `[]` | no |
| <a name="input_puppet_debug_logging"></a> [puppet\_debug\_logging](#input\_puppet\_debug\_logging) | Enable debug logging if true. | `bool` | `false` | no |
| <a name="input_puppet_hiera_config_path"></a> [puppet\_hiera\_config\_path](#input\_puppet\_hiera\_config\_path) | Path to hiera configuration file. | `string` | `"{root_directory}/environments/{environment}/hiera.yaml"` | no |
| <a name="input_puppet_module_path"></a> [puppet\_module\_path](#input\_puppet\_module\_path) | Path to common puppet modules. | `string` | `"{root_directory}/modules"` | no |
| <a name="input_puppet_root_directory"></a> [puppet\_root\_directory](#input\_puppet\_root\_directory) | Path where the puppet code is hosted. | `string` | `"/opt/puppet-code"` | no |
| <a name="input_rds_cloudwatch_logs_retention_days"></a> [rds\_cloudwatch\_logs\_retention\_days](#input\_rds\_cloudwatch\_logs\_retention\_days) | Number of days to retain RDS CloudWatch logs.<br/>Default is 365 days (1 year). Set to 0 for never expire.<br/>Valid values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653 | `number` | `365` | no |
| <a name="input_rds_connections_threshold"></a> [rds\_connections\_threshold](#input\_rds\_connections\_threshold) | RDS database connections threshold for alarms.<br/>Default is 80 - alarm triggers when connection count exceeds this value.<br/>Adjust based on your instance type's max\_connections setting. | `number` | `80` | no |
| <a name="input_rds_cpu_threshold"></a> [rds\_cpu\_threshold](#input\_rds\_cpu\_threshold) | RDS CPU utilization percentage threshold for alarms.<br/>Default is 80% - alarm triggers when CPU exceeds this value. | `number` | `80` | no |
| <a name="input_rds_performance_insights_retention_days"></a> [rds\_performance\_insights\_retention\_days](#input\_rds\_performance\_insights\_retention\_days) | Number of days to retain Performance Insights data.<br/>Valid values: 7 (free tier) or 731 (2 years, additional cost).<br/>Default is 7 days. | `number` | `7` | no |
| <a name="input_rds_storage_threshold_gb"></a> [rds\_storage\_threshold\_gb](#input\_rds\_storage\_threshold\_gb) | RDS free storage space threshold in gigabytes (GB) for alarms.<br/>Default is 5GB - alarm triggers when free space drops below this value. | `number` | `5` | no |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | DNS hostname for the service. It's also used to name some resources like EC2 instances. | `string` | `"bookstack"` | no |
| <a name="input_ses_bounce_rate_threshold"></a> [ses\_bounce\_rate\_threshold](#input\_ses\_bounce\_rate\_threshold) | SES bounce rate percentage threshold (AWS recommends keeping below 5%) | `number` | `0.05` | no |
| <a name="input_ses_complaint_rate_threshold"></a> [ses\_complaint\_rate\_threshold](#input\_ses\_complaint\_rate\_threshold) | SES complaint rate percentage threshold (AWS recommends keeping below 0.1%) | `number` | `0.001` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Specifies whether to skip the final snapshot when the DB instance is deleted. | `bool` | `false` | no |
| <a name="input_smtp_credentials_secret"></a> [smtp\_credentials\_secret](#input\_smtp\_credentials\_secret) | AWS secret name with SMTP credentials.<br/>The secret must contain a JSON with user and password keys. | `string` | `null` | no |
| <a name="input_smtp_key_rotation_days"></a> [smtp\_key\_rotation\_days](#input\_smtp\_key\_rotation\_days) | Number of days between SMTP credential rotations | `number` | `45` | no |
| <a name="input_sns_topic_alarm_arn"></a> [sns\_topic\_alarm\_arn](#input\_sns\_topic\_alarm\_arn) | ARN of SNS topic for Cloudwatch alarms on base EC2 instance. | `string` | `null` | no |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | Name for the SNS topic. If not provided, defaults to '<service\_name>-alarms' | `string` | `null` | no |
| <a name="input_ssh_cidr_block"></a> [ssh\_cidr\_block](#input\_ssh\_cidr\_block) | CIDR range that is allowed to SSH into the backend instances.  Format is a.b.c.d/<prefix>. | `string` | `null` | no |
| <a name="input_storage_encryption_key_arn"></a> [storage\_encryption\_key\_arn](#input\_storage\_encryption\_key\_arn) | KMS key ARN to encrypt RDS instance storage.<br/>If not provided, AWS managed key will be used.<br/>RDS encryption is always enabled. | `string` | `null` | no |
| <a name="input_ubuntu_codename"></a> [ubuntu\_codename](#input\_ubuntu\_codename) | Ubuntu version to use for the elasticsearch node | `string` | `"jammy"` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Domain name zone ID where the website will be available | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the Auto Scaling Group for BookStack instances |
| <a name="output_bookstack_instance_role_arn"></a> [bookstack\_instance\_role\_arn](#output\_bookstack\_instance\_role\_arn) | IAM role ARN assigned to bookstack EC2 instances. |
| <a name="output_bookstack_load_balancer_arn"></a> [bookstack\_load\_balancer\_arn](#output\_bookstack\_load\_balancer\_arn) | ARN of the load balancer for the BookStack website pod. |
| <a name="output_bookstack_urls"></a> [bookstack\_urls](#output\_bookstack\_urls) | List of URLs where bookstack is available. |
| <a name="output_database_address"></a> [database\_address](#output\_database\_address) | Address of the RDS database instance |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the database |
| <a name="output_database_port"></a> [database\_port](#output\_database\_port) | Port of the RDS database instance |
| <a name="output_database_secret_name"></a> [database\_secret\_name](#output\_database\_secret\_name) | Name of the secret containing database credentials |
| <a name="output_rds_instance_identifier"></a> [rds\_instance\_identifier](#output\_rds\_instance\_identifier) | Identifier of the RDS instance. |
| <a name="output_smtp_credentials_last_rotated"></a> [smtp\_credentials\_last\_rotated](#output\_smtp\_credentials\_last\_rotated) | When SMTP credentials were last rotated (creation date of current key) |
| <a name="output_smtp_credentials_next_rotation"></a> [smtp\_credentials\_next\_rotation](#output\_smtp\_credentials\_next\_rotation) | Next SMTP credential rotation date (RFC3339 format) |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | ARN of the SNS topic for alarms |
<!-- END_TF_DOCS -->
