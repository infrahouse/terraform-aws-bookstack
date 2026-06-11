# Getting Started

## Prerequisites

Before deploying this module you need:

- **Terraform** `~> 1.5`.
- **AWS provider `>= 6.0, < 7.0`.** The module dropped support for AWS provider v5.
- **Two AWS provider configurations.** The module requires a default `aws` provider and a second
  `aws.dns` aliased provider used for Route 53. They can point at the same account/region or, if your
  hosted zone lives elsewhere, at a different account.
- **A VPC with subnets.** You supply:
    - `lb_subnet_ids` — subnets for the public-facing Application Load Balancer.
    - `backend_subnet_ids` — subnets for the EC2 instances and RDS (one instance per subnet).
- **A Route 53 hosted zone** (`zone_id`). BookStack is published at
  `https://<service_name>.<zone-domain>` and the ACM certificate is validated in this zone.
- **A second region for ALB access-log replication** (`access_log_replication_region`) that differs
  from your deployment region.
- **A Google OAuth client secret** stored in AWS Secrets Manager, whose **name** you pass as
  `google_oauth_client_secret`.
- **Alarm recipients** (`alarm_emails`). AWS sends SNS subscription confirmation emails that must be
  accepted.

## Required inputs

| Input | Description |
|-------|-------------|
| `environment` | Environment name (e.g. `development`, `production`). |
| `zone_id` | Route 53 hosted zone ID for the service domain. |
| `lb_subnet_ids` | Subnets for the load balancer. |
| `backend_subnet_ids` | Subnets for the instances and database. |
| `access_log_replication_region` | Region for cross-region replication of the ALB access-log bucket (must differ from the deploy region). |
| `google_oauth_client_secret` | Secrets Manager **name** of the Google OAuth client secret. |
| `alarm_emails` | Email addresses subscribed to the alarm SNS topic. |

See [Configuration](configuration.md) for the full set of inputs and their defaults.

## First deployment

1. Configure the two providers and the module (see the [Quick start](index.md#quick-start)).
2. `terraform init`
3. `terraform plan` — review the resources to be created (ALB, ASG, RDS, EFS, SES identity, Secrets
   Manager secrets, CloudWatch alarms, Route 53 records).
4. `terraform apply`
5. **Confirm the SNS email subscriptions** AWS sends to each address in `alarm_emails`.
6. Wait for the instances to finish bootstrapping (Puppet provisions BookStack on each instance), then
   browse to `https://<service_name>.<zone-domain>`.

The ALB health check targets `/login`; the service is marked healthy once BookStack is serving.

## Outputs

| Output | Description |
|--------|-------------|
| `bookstack_urls` | The URLs where BookStack is reachable. |
| `bookstack_load_balancer_arn` | ARN of the Application Load Balancer. |
| `autoscaling_group_name` | Name of the instances' Auto Scaling Group. |
| `bookstack_instance_role_arn` | IAM role ARN attached to the EC2 instances. |
| `database_address` / `database_port` / `database_name` | RDS connection details. |
| `database_secret_name` | Secrets Manager name of the DB master credentials. |
| `rds_instance_identifier` | RDS instance identifier. |
| `sns_topic_arn` | SNS topic for alarms. |
| `smtp_credentials_next_rotation` / `smtp_credentials_last_rotated` | SES SMTP key rotation timestamps. |
| `userdata_size_info` | Cloud-init userdata size vs. the AWS 16 KB limit. |
