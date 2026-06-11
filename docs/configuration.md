# Configuration

This page explains the inputs by topic. The **complete, authoritative list** of variables, types,
and defaults is the auto-generated table in the
[README](https://github.com/infrahouse/terraform-aws-bookstack#readme) (the terraform-docs block).

## Required inputs

| Variable | Description |
|----------|-------------|
| `environment` | Environment name (e.g. `development`, `production`). |
| `zone_id` | Route 53 hosted zone ID; the service is published at `<service_name>.<zone-domain>`. |
| `lb_subnet_ids` | Subnets for the public Application Load Balancer. |
| `backend_subnet_ids` | Subnets for the EC2 instances and RDS. |
| `access_log_replication_region` | Region for cross-region replication of the ALB access-log bucket. **Must differ** from the deploy region. |
| `google_oauth_client_secret` | Secrets Manager **name** of the Google OAuth client secret. |
| `alarm_emails` | Email addresses subscribed to the alarm SNS topic. |

## Naming & DNS

- `service_name` (default `bookstack`) — DNS hostname and resource name prefix.
- `dns_a_records` — A-record hostnames; defaults to `[service_name]`.
- `ubuntu_codename` (default `noble`) — Ubuntu release for the instances.

## Compute (ALB + Auto Scaling Group)

- `instance_type` (default `t3.micro`) — web server instance type.
- `asg_min_size` / `asg_max_size` — default to the number of backend subnets (and +1 for max).
- `asg_health_check_grace_period`, `asg_ami` — health-check grace and an optional explicit AMI.
- `key_pair_name`, `ssh_cidr_block` — SSH access (a key pair is generated if not supplied).

## Database (RDS, via `module.rds`)

- `db_instance_type` (default `db.t3.medium`) — **must be a Performance-Insights-capable class**;
  Performance Insights is enabled unconditionally by the RDS module, so the small burstable classes
  (`db.t3.micro`/`small`, `db.t4g.micro`/`small`) are not valid choices.
- `rds_performance_insights_retention_days` (default `7`) — Performance Insights retention (`7` for
  the free tier, `731` for two years).
- `deletion_protection` (default `true`) and `skip_final_snapshot` (default `false`).
- `storage_encryption_key_arn` — custom KMS key for RDS storage (AWS-managed key if unset).

The database engine is **MySQL 8.4**, Multi-AZ, encrypted, with an **AWS-managed master password**
stored in Secrets Manager. See [Upgrading](upgrading.md) for migrating an existing 8.0 deployment.

## Storage (EFS)

- `efs_encryption_key_arn` — custom KMS key for EFS (AWS-managed key if unset).

## Email (SES)

- `smtp_key_rotation_days` (default `45`, range 30–90) — how often the SES SMTP IAM key rotates.
- `smtp_credentials_secret` — optional pre-existing SMTP credentials secret (for Postfix relay).

## Alarms & notifications

- `alarm_emails` (required) — recipients subscribed to the SNS topic.
- `sns_topic_name`, `alarm_topic_arns`, `sns_topic_alarm_arn` — name the module's topic and/or route
  alarms to additional/external SNS topics.
- `ses_bounce_rate_threshold` (default `0.05`) and `ses_complaint_rate_threshold` (default `0.001`).

!!! note
    `alarm_emails` is also passed to the `rds` and `website-pod` sub-modules, which create their own
    SNS topics and subscriptions. Subscribers therefore receive more than one confirmation email.

## Application delivery

- `bookstack_prebuilt_package_url` — URL of the pre-built BookStack tarball (with `vendor/`) that is
  downloaded to `/var/tmp/bookstack.tar.gz` before Puppet runs. Its BookStack version **must match**
  the version configured in the Puppet profile. Set to `null` to fall back to the stock flow (Puppet
  downloads source and runs `composer install`). See [Architecture](architecture.md#application-delivery).
- `bookstack_prebuilt_package_sha256` — expected SHA-256 of that artifact. It is verified before
  Puppet runs; a mismatch deletes the download and fails the bootstrap (so a tampered/replaced object
  cannot inject code). Update it **together** with `bookstack_prebuilt_package_url`. `null` skips
  verification (not recommended). See [Security](security.md#application-artifact-supply-chain).

## Access logs

- `access_log_force_destroy` — allow Terraform to delete a non-empty ALB access-log bucket.
- `access_log_replication_region` (required) — see above.

## Provisioning (cloud-init / Puppet)

- `packages`, `extra_files`, `extra_repos` — extra packages/files/apt repos added to the instances.
- `puppet_hiera_config_path`, `puppet_module_path`, `puppet_root_directory`, `puppet_debug_logging`.
- `compress_userdata` — gzip the cloud-init userdata to stay under the 16 KB limit.

## IAM

- `extra_instance_profile_permissions` — an additional IAM policy (JSON) merged into the instance
  role.
