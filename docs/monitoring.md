# Monitoring

Observability comes from three places: this module (SES), and the `rds` and `website-pod`
sub-modules (database and load balancer).

## SES reputation alarms (this module)

Two CloudWatch alarms watch the account-level SES reputation metrics and publish to the module's SNS
topic:

| Alarm | Metric | Default threshold |
|-------|--------|-------------------|
| `<service>-ses-bounce-rate` | `AWS/SES Reputation.BounceRate` | `ses_bounce_rate_threshold` = `0.05` (5%) |
| `<service>-ses-complaint-rate` | `AWS/SES Reputation.ComplaintRate` | `ses_complaint_rate_threshold` = `0.001` (0.1%) |

Both use `treat_missing_data = notBreaching`, so they stay quiet when there is no sending volume.

!!! note
    These metrics are **account-level**. If you deploy this module more than once in the same AWS
    account, each deployment creates its own pair of alarms on the same shared metric.

## Database alarms & dashboard (`module.rds`)

The `rds` sub-module ships its own CloudWatch alarms (CPU, memory, free storage, connections, disk
queue depth) and a CloudWatch dashboard, plus its own SNS topic fed from `alarm_emails`. RDS log
exports (error and slow-query logs) and **Performance Insights** are enabled by the module.

## Load balancer alarms (`module.bookstack` / website-pod)

The `website-pod` sub-module provides ALB alarms (unhealthy hosts, target response time, success
rate, etc.), also fed from `alarm_emails` / `sns_topic_alarm_arn`.

## SNS topics & subscriptions

- This module creates an SNS topic (`sns_topic_name`, default `<service>-alarms`) and subscribes
  every address in `alarm_emails`.
- `alarm_topic_arns` / `sns_topic_alarm_arn` route alarms to additional/external topics.

!!! warning
    Because `alarm_emails` is forwarded to the `rds` and `website-pod` sub-modules as well, each
    subscriber receives a confirmation email from **each** topic. Confirm all of them, or consolidate
    by pointing the sub-modules at a shared topic.

## SES SMTP key rotation

The SES SMTP IAM access key rotates on a `time_rotating` schedule (`smtp_key_rotation_days`, default
45). The current rotation state is exposed via outputs:

- `smtp_credentials_next_rotation`
- `smtp_credentials_last_rotated`

## Userdata size

Cloud-init userdata must fit AWS's 16 KB limit. The `userdata_size_info` output reports current
utilization, remaining bytes, and a status (`OK` / `APPROACHING LIMIT` / `EXCEEDS LIMIT`). Enable
`compress_userdata` if you approach the cap.
