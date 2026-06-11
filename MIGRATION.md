# Migration: hand-rolled RDS → `module.rds`, MySQL 8.0 → 8.4 (cold cutover)

This release replaces the in-module `aws_db_instance.db` with the
`registry.infrahouse.com/infrahouse/rds/aws` module and pins MySQL **8.4**. The registry
module cannot adopt the existing instance (it owns the DB subnet group and identifier), so the
data must be moved with a **logical dump/restore** into a fresh 8.4 instance. Because the dump is
logical, it doubles as the 8.0 → 8.4 engine upgrade — the schema is recreated by 8.4, so there is
no in-place datadir upgrade, and only the application database moves (not users), so the
`mysql_native_password` → `caching_sha2_password` change in 8.4 is a non-issue.

**This procedure assumes downtime is acceptable.** Writes are stopped for the duration so a single
cold dump is consistent — no incremental catch-up needed.

## Why a dump/restore (and not a `moved {}` block or in-place upgrade)

This question tends to get re-litigated, so to settle it accurately:

- **The migration does not *inherently* recreate the database.** Of the attributes that change,
  `engine_version` (8.0→8.4, an in-place major upgrade), `identifier` (in-place rename), and
  `db_subnet_group_name` are **not** `ForceNew` in the AWS provider — only `username` is, and you can
  keep it matching (`<service_name>_user`). So in principle a `moved` block
  (`moved { from = aws_db_instance.db, to = module.rds.aws_db_instance.this }`, which is valid
  Terraform) *could* adopt the existing instance in place.
- **A plain `terraform apply` with no `moved` block *does* recreate** — but only because Terraform
  sees the old `aws_db_instance.db` removed (→ destroy) and `module.rds.aws_db_instance.this` added
  (→ create) as two unrelated resources. That is why the snapshot/dump-before-apply ordering below
  matters.
- **We choose dump/restore as a trade-off, not a necessity.** The in-place `moved` path is unproven
  and risky: it would do a simultaneous in-place rename + subnet-group change + major engine upgrade
  + switch to an AWS-managed master password against a registry module we don't control, while
  Terraform also destroys the old subnet/parameter/security groups — with the production DB as the
  blast radius. It also hard-codes the module's internal resource name (fragile across module
  versions) and runs against HashiCorp's guidance that moved-into-module is for module packages you
  author. A logical dump/restore is far simpler, fully reversible (the old instance is left
  untouched), folds the 8.0→8.4 upgrade into the data move, and is more than adequate given downtime
  is acceptable and the dataset is small.

> ⚠️ `terraform apply` of this version **destroys** the old `aws_db_instance.db`. Take the snapshot
> and the dump **before** applying. The snapshot is your rollback.

## 0. Pre-flight
- Note the **old** DB endpoint + master credentials (current Secrets Manager `bookstack_db` secret).
- If the old instance has `deletion_protection = true`, set `deletion_protection = false` and apply
  *just that* first, or the destroy in step 4 will fail.
- Run the dump from a host with network access to the old RDS (a bastion / one of the current
  instances). Use a **MySQL 8.4 `mysqldump`** binary (client ≥ the highest server version).

## 1. Stop writes
Put BookStack into maintenance and stop the app from writing:
```bash
# on the instances, or scale the ASG desired capacity to 0
php artisan down
```

## 2. Manual snapshot (rollback safety net)
```bash
aws rds create-db-snapshot \
  --db-instance-identifier <old-identifier> \
  --db-snapshot-identifier bookstack-pre-8.4-migration \
  --region <region>
aws rds wait db-snapshot-completed \
  --db-snapshot-identifier bookstack-pre-8.4-migration --region <region>
```

## 3. Dump the old 8.0 database (cold, so consistent)
```bash
mysqldump \
  --host=<old-endpoint> --user=<old-master> -p \
  --single-transaction \
  --set-gtid-purged=OFF \      # required on RDS, else restore fails on GTID
  --no-tablespaces \           # RDS user lacks the PROCESS privilege
  --routines --triggers --events \
  bookstack > bookstack.sql    # the app DB only — NOT mysql/sys/users
```
If BookStack has any `DEFINER`-bearing views/triggers and the restore later errors on them, strip
them: `sed -E 's/DEFINER=`[^`]+`@`[^`]+`//g' bookstack.sql > bookstack-clean.sql`.

## 4. Apply the new module
```bash
terraform apply
```
This destroys the old instance and creates `module.rds` (a fresh, **empty** 8.4 instance), the
AWS-managed master secret, and repoints the Puppet `custom_facts` at the new DB. New instances boot
and Puppet may run `php artisan migrate` against the empty DB — that's fine, the next step
overwrites it (`mysqldump` emits `DROP TABLE IF EXISTS` before each `CREATE`).

Grab the new connection details:
```bash
NEW_ENDPOINT=$(terraform output -raw database_address)
NEW_SECRET=$(terraform output -raw database_secret_name)
# password lives in Secrets Manager under $NEW_SECRET (key "password")
```

## 5. Load the dump into the new 8.4 instance
```bash
mysql --host="$NEW_ENDPOINT" --user=<new-master> -p bookstack < bookstack.sql
```

## 6. Bring the app back and verify
```bash
php artisan migrate --force   # should report nothing pending (or apply BookStack-version upgrades)
php artisan up
```
Smoke test: log in, open a few pages, confirm image/upload rendering (EFS), run a search.

## 7. Cleanup / rollback
- **Success:** keep the `bookstack-pre-8.4-migration` snapshot for a few days, then delete it.
- **Rollback:** restore `bookstack-pre-8.4-migration` to a new 8.0 instance and point BookStack back
  at it (the old live instance no longer exists after step 4 — the snapshot is the rollback).

## Notes
- BookStack supports MySQL 8.4 (its own installers ship 8.4); no app-level changes are needed.
- The module enables Performance Insights unconditionally, so `db_instance_type` must be a
  PI-capable class (default is now `db.t3.medium`).
- If you want a live old instance as rollback (instead of a snapshot), run the migration in two
  phases — keep the old `db.tf` alongside `module.rds` for the dump/restore, then remove it in a
  follow-up apply — at the cost of more steps.
