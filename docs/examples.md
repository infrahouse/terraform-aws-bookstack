# Examples

All examples assume the two providers are configured (default `aws` and `aws.dns`) and that the
referenced subnets/zone exist.

## Minimal

```hcl
module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "3.4.0" # always pin an exact release

  providers = {
    aws     = aws
    aws.dns = aws.dns
  }

  service_name                  = "wiki"
  environment                   = "production"
  zone_id                       = data.aws_route53_zone.this.zone_id
  lb_subnet_ids                 = var.public_subnet_ids
  backend_subnet_ids            = var.private_subnet_ids
  access_log_replication_region = "us-east-1"
  google_oauth_client_secret    = "bookstack_google_oauth"
  alarm_emails                  = ["ops@example.com"]
}
```

## Customer-managed KMS keys

```hcl
module "bookstack" {
  # ... required inputs ...
  storage_encryption_key_arn = aws_kms_key.rds.arn
  efs_encryption_key_arn     = aws_kms_key.efs.arn
}
```

## Larger database and longer Performance Insights retention

```hcl
module "bookstack" {
  # ... required inputs ...
  db_instance_type                        = "db.r6g.large" # PI-capable class
  rds_performance_insights_retention_days = 731            # 2 years
  deletion_protection                     = true
}
```

## Route alarms to an existing SNS topic (PagerDuty/Slack)

```hcl
module "bookstack" {
  # ... required inputs ...
  alarm_emails        = ["ops@example.com"]
  alarm_topic_arns    = [aws_sns_topic.pagerduty.arn]
  sns_topic_name      = "wiki-alarms"
}
```

## Sizing the Auto Scaling Group

```hcl
module "bookstack" {
  # ... required inputs ...
  instance_type = "t3.small"
  asg_min_size  = 2
  asg_max_size  = 4
}
```

## SSH access for debugging

```hcl
module "bookstack" {
  # ... required inputs ...
  key_pair_name  = aws_key_pair.ops.key_name
  ssh_cidr_block = "10.0.0.0/8"
}
```

## Pin (or disable) the pre-built application artifact

```hcl
module "bookstack" {
  # ... required inputs ...

  # Pin to a specific pre-built tarball (must match the Puppet BookStack version):
  bookstack_prebuilt_package_url = "https://example.s3.amazonaws.com/bookstack/bookstack-v25.02.1-vendor.tar.gz"

  # ...or disable it and let Puppet download source + run composer at boot:
  # bookstack_prebuilt_package_url = null
}
```

## Add extra OS packages or files

```hcl
module "bookstack" {
  # ... required inputs ...
  packages = ["htop", "jq"]
  extra_files = [
    {
      content     = file("${path.module}/files/motd")
      path        = "/etc/motd"
      permissions = "0644"
    }
  ]
}
```
