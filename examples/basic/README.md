# Basic Example

The minimum configuration required to deploy BookStack with the
terraform-aws-bookstack module.

## What This Example Creates

- VPC with two public and two private subnets (one NAT gateway)
- Application Load Balancer with an HTTPS listener and an ACM certificate
- Auto Scaling Group of Ubuntu Pro instances running BookStack
- Multi-AZ encrypted RDS MySQL instance
- Encrypted EFS file system for uploads and images, mounted on every instance
- SES IAM user with auto-rotating SMTP credentials
- Secrets Manager secrets for the app key, the database and the SMTP password
- SNS topic with email subscriptions and CloudWatch alarms
- DNS record `bookstack.example.com` pointing at the load balancer

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- A Route 53 hosted zone for your domain (`example.com` here)
- The domain verified in SES, with the account out of the SES sandbox
- A Google OAuth client (Google Cloud Console → APIs & Services → Credentials)

## Usage

```bash
terraform init
terraform apply -var="google_oauth_client_json=$(cat ~/google_client.json)"
```

Then open the URL:

```bash
terraform output bookstack_urls
```

The first instance takes several minutes to bootstrap: cloud-init installs the
packages and Puppet configures BookStack before the ALB health check passes.

## Inputs

| Name | Description |
|------|-------------|
| google_oauth_client_json | Contents of the Google OAuth client JSON |

## Outputs

| Name | Description |
|------|-------------|
| bookstack_urls | URLs where BookStack is available |
| database_address | Address of the RDS instance |
| userdata_size_info | How much of the 16KB EC2 userdata limit is used |

## Notes

- Replace `example.com` with your actual domain. The zone is looked up with a
  data source, so it must exist before `terraform apply`.
- `access_log_replication_region` must differ from the region the module is
  deployed to — the ALB access log bucket is replicated cross-region.
- The Google OAuth secret lists the BookStack instance role in `readers`. That
  is what lets the instances read the client id and secret at boot.
- For a non-production deployment, add `deletion_protection = false`,
  `skip_final_snapshot = true` and `access_log_force_destroy = true` so
  `terraform destroy` completes without manual cleanup.
