# Production Example

A production-shaped deployment: an existing VPC, customer-managed KMS keys,
several DNS names, a three-instance fleet and alarms routed to PagerDuty.

## What This Example Shows

- **Existing network**: subnet ids are passed in instead of creating a VPC
- **Cross-account DNS**: the `aws.dns` provider assumes a role in the account
  that owns the hosted zone
- **Customer-managed encryption**: dedicated KMS keys with rotation enabled for
  the RDS storage and the EFS file system
- **Multiple hostnames**: `bookstack`, `wiki` and `docs` records point at the
  same load balancer
- **Alerting integrations**: alarms go to the on-call inbox and to an existing
  PagerDuty SNS topic, with tighter SES reputation thresholds
- **Data protection**: RDS deletion protection on and a final snapshot on delete
- **Userdata compression**: keeps the instance userdata under the AWS 16KB limit
  when extra packages are installed

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- An existing VPC with public subnets for the load balancer and private subnets
  (with NAT) for the instances, RDS and EFS
- A Route 53 hosted zone and an IAM role in the DNS account that can manage it
- The domain verified in SES, with the account out of the SES sandbox
- An SNS topic subscribed to by PagerDuty
- A Google OAuth client whose redirect URIs cover every DNS name above

## Usage

```bash
terraform init
terraform apply \
  -var='lb_subnet_ids=["subnet-aaa","subnet-bbb","subnet-ccc"]' \
  -var='backend_subnet_ids=["subnet-ddd","subnet-eee","subnet-fff"]' \
  -var='zone_id=Z1234567890ABC' \
  -var='dns_role_arn=arn:aws:iam::123456789012:role/dns-manager' \
  -var='alarm_emails=["oncall@example.com"]' \
  -var='pagerduty_topic_arn=arn:aws:sns:us-west-2:123456789012:pagerduty-critical' \
  -var="google_oauth_client_json=$(cat ~/google_client.json)"
```

## Outputs

| Name | Description |
|------|-------------|
| bookstack_urls | URLs where BookStack is available |
| bookstack_zone_name | Route 53 zone the BookStack records are created in |
| smtp_credentials_next_rotation | When the SES SMTP credentials are rotated next |
| sns_topic_arn | SNS topic the module publishes alarms to |

## Notes

- `db_instance_type` must support RDS Performance Insights, which the RDS module
  enables unconditionally. `db.t3.micro`, `db.t3.small`, `db.t4g.micro` and
  `db.t4g.small` are therefore not valid choices.
- `access_log_replication_region` has to differ from the deployment region.
- The KMS keys are created by this configuration, so `terraform destroy`
  schedules them for deletion after 30 days. Keys still referenced by RDS
  snapshots or EFS backups must be retained for as long as those exist.
- Rotating the SES SMTP credentials every 30 days means a `terraform apply` runs
  at least that often — otherwise the rotation only happens on the next apply.
