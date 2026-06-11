# Troubleshooting

## `terraform apply` fails: missing provider `aws.dns`

The module requires a second, aliased AWS provider for Route 53. Pass it explicitly:

```hcl
providers = {
  aws     = aws
  aws.dns = aws.dns
}
```

## `terraform apply` fails: Performance Insights / invalid `db_instance_type`

The RDS module enables Performance Insights unconditionally, which is unsupported on the small
burstable classes. Use a PI-capable class — the default is `db.t3.medium`. `db.t3.micro`/`small` and
`db.t4g.micro`/`small` will fail.

## `RDS InvalidParameterCombination: Invalid storage size ... gp3`

MySQL on gp3 has a 20 GiB minimum. The module sets `allocated_storage = 20`; do not lower it below
the gp3 floor.

## ALB targets never become healthy / instances keep cycling

The ALB health check targets `/login`. If instances never pass it and the ASG keeps replacing them,
Puppet provisioning is failing. SSH in (or use SSM) and check:

- `ls -l /var/run/puppet-done` — created only when Puppet finishes successfully.
- The Puppet/bootstrap log for the failing resource.
- That the application artifact downloaded: `/var/tmp/bookstack.tar.gz` should exist and the app
  should be present under `/var/www/bookstack` with `vendor/autoload.php`.

## Database access denied

If BookStack reports `Access denied for user`, the password delivered to the app doesn't match.
With the AWS-managed master password this is almost always a special-character quoting issue in the
application config or the connectivity check — the password is passed verbatim (no `.env`/option-file
parsing pitfalls). Confirm the instance can read the `database_secret_name` secret and that the value
authenticates directly against the endpoint.

## Userdata exceeds the 16 KB limit

Check the `userdata_size_info` output. If `status` is `EXCEEDS LIMIT` or `APPROACHING LIMIT`, set
`compress_userdata = true`, or reduce `packages`/`extra_files`.

## No alarm emails / duplicate alarm emails

- **None:** confirm the SNS subscription emails AWS sends to each `alarm_emails` address.
- **Duplicates:** `alarm_emails` is forwarded to the `rds` and `website-pod` sub-modules, which each
  create their own topic and subscription — so you get a confirmation from each. Confirm them all or
  consolidate onto a shared topic.

## SES email not sending

In a new account SES starts in the sandbox (verified recipients only) with low quotas. Move SES out
of the sandbox for production sending. The IAM policy also restricts the `FromAddress` to the Route 53
zone domain.

## `access_log_replication_region` errors / same-region replication

`access_log_replication_region` must differ from the deployment region (it is the cross-region
replication target for the ALB access-log bucket).
