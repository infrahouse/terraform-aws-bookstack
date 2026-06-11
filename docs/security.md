# Security

## Encryption

- **RDS** — storage is always encrypted (AWS-managed key by default, or `storage_encryption_key_arn`).
- **EFS** — always encrypted (AWS-managed key by default, or `efs_encryption_key_arn`).
- **In transit** — the ALB terminates TLS with an ACM certificate validated in your Route 53 zone;
  SES SMTP uses TLS on port 587.

## Secrets

All sensitive values live in AWS Secrets Manager, readable only by the EC2 instance role:

| Secret | Contents | Manager |
|--------|----------|---------|
| App key | BookStack `APP_KEY` | `module.bookstack_app_key` |
| DB master credentials | RDS-managed master username/password | `module.rds` (AWS-managed) |
| SES SMTP password | SES SMTP password | `module.ses_smtp_password` |
| Google OAuth client secret | OAuth client secret | supplied by the caller (`google_oauth_client_secret`) |

The instance-profile IAM policy (`datasources.tf`) grants `secretsmanager:GetSecretValue` on exactly
these four secret ARNs — nothing broader.

!!! note "Master credential scope"
    The RDS module uses an **AWS-managed master password**, and the application reads it via the
    `database_secret_name`. This means the EC2 role can read the database **master/superuser**
    credential rather than a narrowly-scoped application user. If you require least-privilege DB
    access, provision a dedicated application user as a follow-up and point BookStack at it.

## Network posture

- The **RDS** security group (managed by `module.rds`) allows MySQL only from within the VPC CIDR.
- The **EFS** security group allows NFS only from within the VPC CIDR.
- SSH is closed by default; open it explicitly with `ssh_cidr_block` (+ `key_pair_name`).

## Email sending restrictions

The SES IAM user's policy restricts the `FromAddress` to the Route 53 zone domain, so the instances
cannot send mail from arbitrary domains. The SMTP IAM access key auto-rotates on the
`smtp_key_rotation_days` schedule.

## Application artifact (supply chain)

`bookstack_prebuilt_package_url` is downloaded over HTTPS at boot and unpacked into the application's
`vendor/` directory. It is **integrity-checked**: the boot-time `pre_runcmd` verifies the download
against `bookstack_prebuilt_package_sha256` and, on a mismatch (a tampered or replaced object, or a
corrupt download), deletes the file and fails the bootstrap — so untrusted code is never unpacked
into the application. This also pins the content: swapping the object without updating the hash will
fail verification rather than silently ship new code.

Still treat the hosting location as a supply-chain dependency:

- Serve it from a location **you control** and whose write access is restricted.
- Keep `bookstack_prebuilt_package_url` and `bookstack_prebuilt_package_sha256` updated **together**.
- Setting `bookstack_prebuilt_package_sha256 = null` disables verification (not recommended); setting
  `bookstack_prebuilt_package_url = null` falls back to building dependencies at boot instead.

## Provider isolation

The `aws.dns` aliased provider lets Route 53 records be managed in a separate account from the
application resources, supporting an isolated DNS account if your organization uses one.
