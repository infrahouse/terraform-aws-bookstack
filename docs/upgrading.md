# Upgrading

## 3.x → 4.x (RDS module + MySQL 8.4) — breaking

This major version replaces the in-module `aws_db_instance` with the InfraHouse `rds` module and pins
**MySQL 8.4**. It is a breaking change for both callers and existing deployments.

### Breaking changes

- **Database engine and ownership.** RDS is now created by `module.rds` at **MySQL 8.4**. The
  Terraform address of the instance changes, and the registry module cannot adopt the existing
  instance — so a plain `apply` would **destroy and recreate** the database. Data must be migrated
  with a logical dump/restore. **See the [cold-cutover runbook](#database-migration-runbook).**
- **New required inputs:** `environment` (the default was removed) and `access_log_replication_region`.
- **AWS provider v5 dropped.** The constraint is now `>= 6.0, < 7.0`.
- **`db_instance_type` default** moved `db.t3.micro` → `db.t3.medium` (Performance Insights is now
  unconditional and unsupported on the small burstable classes).
- **website-pod 6.x.** `internet_gateway_id` and `alb_access_log_enabled` are removed; cross-region
  access-log replication (`access_log_replication_region`) is required.
- **Removed inputs:** the per-alarm RDS threshold variables and `enable_rds_*` toggles (RDS alarms are
  now provided by `module.rds`), plus `db_identifier` and `enable_ses_alarms` (SES alarms are always
  on).

### Behavior changes to note

- Performance Insights is always on (retention via `rds_performance_insights_retention_days`).
- RDS log exports are error + slow-query only (the previous `general` log export is gone).
- `alarm_emails` is now also consumed by the `rds` and `website-pod` sub-modules, so subscribers
  receive multiple SNS confirmation emails.

### Database migration runbook

Migrating an existing MySQL 8.0 deployment to the 8.4 `module.rds` instance is a **logical
dump/restore** (which doubles as the 8.0→8.4 upgrade — the schema is rebuilt by 8.4, and only the
application database moves). The full step-by-step runbook (cold cutover, downtime acceptable) lives
in the repository at **[`MIGRATION.md`](https://github.com/infrahouse/terraform-aws-bookstack/blob/main/MIGRATION.md)**.

In short:

1. Stop writes (`php artisan down` / scale the ASG to 0).
2. Snapshot the old instance (rollback safety net) and disable its `deletion_protection`.
3. `mysqldump` the old 8.0 database (`--set-gtid-purged=OFF --no-tablespaces --single-transaction`).
4. `terraform apply` this version (creates the empty 8.4 `module.rds` instance; destroys the old one).
5. Load the dump into the new instance (`mysqldump`'s default `DROP TABLE IF EXISTS` cleanly replaces
   any schema Puppet created).
6. Bring the app up, run `php artisan migrate --force`, and verify (login, pages, uploads, search).

!!! warning
    Take the snapshot **and** the dump **before** running `terraform apply` — the apply destroys the
    old instance, after which the snapshot is your only rollback.

BookStack officially supports MySQL 8.4, so no application-level changes are required.
