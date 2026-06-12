# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is an InfraHouse Terraform module that deploys [BookStack](https://www.bookstackapp.com/)
(an open-source wiki) on AWS as a highly available, encrypted, monitored service.

## First Steps

**Your first tool call in this repository MUST be reading .claude/CODING_STANDARD.md.
Do not read any other files, search, or take any actions until you have read it.**
This contains InfraHouse's comprehensive coding standards for Terraform, Python, and general formatting rules.

## Commands

```bash
make bootstrap     # Install pip deps (requirements.txt) and git hooks; run once per clone
make lint          # terraform fmt --check -recursive (no changes)
make fmt           # terraform fmt -recursive + black on tests/
make test          # Run the full pytest suite
make test-clean    # Run the `aws-6` test, destroy AWS resources after (use before a PR)
make test-keep     # Run the `aws-6` test, keep AWS resources for debugging
```

Run a single test directly with pytest (tests create **real AWS infrastructure** in the
InfraHouse test account `303467602807`, region `us-west-2`, assuming role `bookstack-tester`):

```bash
pytest -xvvs --aws-region=us-west-2 \
  --test-role-arn=arn:aws:iam::303467602807:role/bookstack-tester \
  -k aws-6 tests/test_module.py        # add --keep-after to retain resources
```

`test_module` is parametrized over AWS provider `~> 5.62` (`aws-5`) and `~> 6.0` (`aws-6`);
`-k aws-6` selects one. Tests apply the module, wait for Puppet to finish on an instance
(`/tmp/puppet-done`), run an in-instance DB connectivity script, and assert userdata stays
under the AWS 16 KB limit.

## Architecture

The module composes two InfraHouse registry modules in `main.tf`, then wires AWS resources
to them. Source files are split by concern (Terraform loads all `*.tf` regardless of name):

- **`main.tf`** — the heart. Instantiates `module.bookstack-userdata`
  (`infrahouse/cloud-init/aws`) and `module.bookstack` (`infrahouse/website-pod/aws`, which
  provides the ALB + Auto Scaling Group). Application config is injected into the instances
  via the cloud-init module's `custom_facts` (Puppet Hiera facts): DB host/credentials, EFS
  mount, SES mail settings, Google OAuth secret, app key. The website-pod's
  `instance_profile_permissions` comes from `data.aws_iam_policy_document.instance_permissions`
  in `datasources.tf`, granting the EC2 role read access to exactly the four secrets used.
- **`db.tf`** — Multi-AZ encrypted RDS MySQL 8.0, custom parameter group (`binlog_format=ROW`),
  CloudWatch log exports, and conditional Performance Insights.
- **`efs.tf`** — Encrypted EFS for shared uploads/images, mount targets per backend subnet,
  NFS security group scoped to the VPC CIDR.
- **`smtp.tf`** — SES sending via a dedicated IAM user whose access key auto-rotates on a
  `time_rotating` schedule (`smtp_key_rotation_days`); IAM policy restricts `FromAddress` to
  the Route 53 zone domain.
- **`secrets.tf`** — App key, DB credentials, and SES SMTP password stored in Secrets Manager
  via `infrahouse/secret/aws`, each readable only by the EC2 instance role.
- **`alarms.tf` / `cloudwatch-logs.tf` / `sns.tf`** — RDS + SES CloudWatch alarms publishing
  to an SNS topic with email subscriptions.
- **`locals.tf`** — Derived names, SES SMTP endpoints per region, and the
  Performance-Insights-unsupported instance-type blocklist (PI is auto-disabled for those).

### Key cross-cutting concerns

- **Provider aliases**: callers must pass `aws.dns` (a second AWS provider for Route 53), in
  addition to the default `aws`. See `terraform.tf` required_providers.
- **Userdata 16 KB limit**: cloud-init userdata must fit AWS's 16 KB cap. The
  `userdata_size_info` output reports utilization; `var.compress_userdata` gzips it. The test
  suite fails if the limit is exceeded — be mindful when adding `packages` or `extra_files`.
- **Module version**: `local.module_version` in `locals.tf` and `version` strings in
  `README.md` are kept in sync with `.bumpversion.cfg` (`current_version`). Bump releases with
  `bumpversion` — do not hand-edit these.

## Conventions & workflow

- **Coding standards** live in `.claude/CODING_STANDARD.md` (Terraform/Python/formatting) and
  module requirements in `.claude/TERRAFORM_MODULE_REQUIREMENTS.md`.
- **Pre-commit hook** (`hooks/pre-commit`, installed by `make install-hooks`) enforces
  `terraform fmt`, regenerates the README's terraform-docs section, and rejects files without a
  trailing newline. The hook is managed externally by the `infrahouse/github-control` repo — do
  not edit `hooks/` by hand.
- **README** has an auto-generated terraform-docs block (config in `.terraform-docs.yml`);
  edit variable/output descriptions in the `.tf` files, not the generated table.
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `refactor:`); enforced by the `commit-msg` hook.
- End every file with a newline.
