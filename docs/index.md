# InfraHouse bookstack

Terraform module that deploys [BookStack](https://www.bookstackapp.com/) — an open-source wiki and
documentation platform — on AWS as a highly available, encrypted, and monitored service.

It composes the InfraHouse building-block modules ([website-pod](https://registry.terraform.io/modules/infrahouse/website-pod/aws/latest),
[rds](https://registry.terraform.io/modules/infrahouse/rds/aws/latest),
[cloud-init](https://registry.terraform.io/modules/infrahouse/cloud-init/aws/latest),
[secret](https://registry.terraform.io/modules/infrahouse/secret/aws/latest)) and wires the
surrounding AWS resources (EFS, SES, Secrets Manager, CloudWatch) into a single, opinionated stack.

## Features

- **Highly available compute** — an Auto Scaling Group of EC2 instances behind an Application Load
  Balancer (ACM/HTTPS, access logs, sticky sessions), one instance per backend subnet.
- **Managed MySQL** — Multi-AZ, encrypted **MySQL 8.4** RDS via the InfraHouse `rds` module, with an
  AWS-managed master password, automated backups, Performance Insights, and built-in CloudWatch
  alarms + dashboard.
- **Shared storage** — encrypted EFS for BookStack uploads and images, mounted on every instance.
- **Email** — SES sending through a dedicated IAM user whose SMTP credentials auto-rotate; sending
  is restricted to the service's Route 53 domain.
- **Authentication** — Google OAuth (the client secret is read from Secrets Manager).
- **Secrets** — the app key, SES SMTP password, and DB master credentials live in AWS Secrets
  Manager, readable only by the EC2 instance role.
- **Encryption everywhere** — RDS and EFS are always encrypted (AWS-managed keys by default, custom
  KMS keys supported).
- **Reliable boot** — application code (including the composer `vendor/` directory) is delivered as a
  pre-built artifact, so instances bootstrap deterministically without building dependencies at boot.

## Quick start

```hcl
provider "aws" {
  region = "us-west-2"
}

# Second provider for Route 53 (the zone may live in another account).
provider "aws" {
  alias  = "dns"
  region = "us-west-2"
}

module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "4.1.0" # always pin an exact release

  providers = {
    aws     = aws
    aws.dns = aws.dns
  }

  service_name                  = "wiki"
  environment                   = "production"
  zone_id                       = data.aws_route53_zone.this.zone_id
  lb_subnet_ids                 = var.public_subnet_ids
  backend_subnet_ids            = var.private_subnet_ids
  access_log_replication_region = "us-east-1"             # must differ from the deploy region
  google_oauth_client_secret    = "bookstack_google_oauth" # Secrets Manager secret name
  alarm_emails                  = ["ops@example.com"]
}
```

BookStack becomes available at `https://<service_name>.<zone-domain>` once the instances finish
bootstrapping.

## Next steps

- [Getting Started](getting-started.md) — prerequisites and your first deployment.
- [Architecture](architecture.md) — what gets created and how it fits together.
- [Configuration](configuration.md) — the inputs that matter.
- [Examples](examples.md) — common configurations.
- [Monitoring](monitoring.md) — alarms, dashboards, logs.
- [Security](security.md) — encryption, secrets, IAM, network posture.
- [Troubleshooting](troubleshooting.md) — common issues.
- [Upgrading](upgrading.md) — migration runbooks (including the RDS-module / MySQL 8.4 migration).
