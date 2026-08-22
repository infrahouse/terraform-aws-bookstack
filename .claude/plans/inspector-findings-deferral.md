# Task: enable `defer_inspector_findings_until_patched` + grant `ec2:DeleteTags`

**Status:** implemented 2026-08-22. Both prerequisites went live earlier the same day.

## Why

AWS Inspector reports findings against a freshly launched instance before `unattended-upgrades` has run.
The finding closes on the next upgrade, but it has already **reopened its vulnerability group** by then, and
a group old enough to be reopened that way breaks the remediation SLA.

```
launch  -> instance tagged InspectorEc2Exclusion   (website-pod, flag off by default)
boot    -> apt-get update && unattended-upgrade    (puppet-code, profile::boot_security_upgrade)
success -> aws ec2 delete-tags Key=InspectorEc2Exclusion   (needs IAM from THIS module)
        -> Inspector's first findings describe a patched host
```

Already shipped this way: `terraform-aws-jumphost` v6.1.0, `terraform-aws-openvpn` v10.2.0.

## ⚠️ Prerequisites (both satisfied 2026-08-22)

**The tag is fail-open.** An instance that launches tagged with nothing to remove the tag is **permanently
invisible to Inspector** — silently worse than never tagging at all. On a singleton wiki that state can
persist indefinitely, because nothing replaces the instance on a schedule.

1. **puppet-code #298** — `role::bookstack` includes `profile::boot_security_upgrade`. Must be **merged and
   deployed to the instances**, not just merged. That is the only thing that removes the tag.
   ✅ Merged 19:30Z; the Puppet Code Continuous Deployment run for it succeeded.
2. **terraform-aws-website-pod #132** — adds `defer_inspector_findings_until_patched`. Must be released.
   ✅ Released as **6.5.0** at 19:53Z.

Both changes below then land in **one PR**. There is no useful intermediate state.

## Change 1 — bump website-pod and set the flag (`main.tf`)

In the `module "bookstack"` block (~line 88), bump `version` past #132's release and add:

```hcl
  # Suppress Inspector findings until profile::boot_security_upgrade has applied
  # pending security updates and removed the tag. REQUIRES the ec2:DeleteTags
  # statement in datasources.tf and role::bookstack having the profile deployed --
  # see .claude/plans/inspector-findings-deferral.md.
  defer_inspector_findings_until_patched = true
```

Do **not** route this through the existing `tags` argument instead. It would work — `var.tags` reaches
instances via website-pod's `default_module_tags` → `default_asg_tags` → `propagate_at_launch = true` — but
`default_module_tags` is also applied to the ALB, the S3 access-log buckets, every security group, the
CloudWatch alarms, Glue, ACM and IAM. That stamps `InspectorEc2Exclusion` on an S3 bucket.

## Change 2 — grant `ec2:DeleteTags` (`datasources.tf`)

Add to `data.aws_iam_policy_document.instance_permissions` (~line 44). It is already wired to the instance
profile via `instance_profile_permissions` in the module block, so no website-pod change is needed:

```hcl
  # Lets profile::boot_security_upgrade drop the InspectorEc2Exclusion tag once
  # security updates are applied. Scoped to this tag key, to instances, and to
  # instances this module created.
  statement {
    actions   = ["ec2:DeleteTags"]
    resources = ["arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"]
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = ["InspectorEc2Exclusion"]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/created_by_module"
      values   = ["infrahouse/bookstack/aws"]
    }
  }
```

`data.aws_caller_identity.current` is already used in `locals.tf` (`ec2_role_arn`).

### Why `created_by_module` here, and not openvpn's ASG-name condition

openvpn scopes on `ec2:ResourceTag/aws:autoscaling:groupName` using `local.asg_name`, which is tighter. That
does **not** transfer to this module, for two reasons:

- **This module does not own the ASG name.** website-pod generates it from `name_prefix` unless
  `var.asg_name` is passed. The `asg_name` *output* is `aws_autoscaling_group.website.name` — a resource
  reference — so using it would order the grant *after* the ASG has begun launching tagged instances, which
  is precisely the fail-open window this plan exists to close.
- **Passing `var.asg_name` to fix that would replace the ASG.** `name` is ForceNew on
  `aws_autoscaling_group`, so switching an existing deployment from a generated `name_prefix` to an explicit
  name destroys and recreates the group. Not worth it for IAM scoping on a singleton.

`created_by_module` is a static string, so it carries no ordering hazard, and it is accurate here:
`local.tags` sets `created_by_module = "infrahouse/bookstack/aws"`, and website-pod merges `var.tags` **last**
into `default_module_tags`, so it overrides website-pod's own value on the instances. Same approach jumphost
shipped.

## ⚠️ The bookstack-specific risk: ALB health-check grace period

BookStack is the **first target of this pattern behind an ALB HTTP health check**. jumphost and openvpn sit
behind NLBs whose TCP checks pass as soon as sshd or openvpn binds — long before the app stack is up. Here
`alb_healthcheck_path = "/login"` must return 200, which needs Apache, PHP and the app fully configured.

`main.tf` sets `health_check_grace_period = var.asg_health_check_grace_period`, default **600s**.

Boot patching adds wall clock inside that window. The normal path is a single
`apt-get update -qq && unattended-upgrade` — tens of seconds. But `profile::boot_security_upgrade` has a
**480s budget**, consumed under dpkg-lock contention (the Inspector and GuardDuty agents both dpkg-install
about a minute into every boot), and ih-puppet applies the catalog twice — measured ~506s for the first
apply alone on a comparable module. Worst case pushes past the 10-minute grace period and the ASG replaces
an instance that was only still patching.

Watch the first launch. Two levers, neither needed up front:

- lower the budget for this role in puppet-code hiera — `profile::boot_security_upgrade::budget` in
  `bookstack.yaml` (all three environments)
- raise `asg_health_check_grace_period` here

**Unrelated bug noticed nearby:** `var.asg_health_check_grace_period` is described as "minutes" and used
*both* ways — as seconds for `health_check_grace_period` and as minutes for `wait_for_capacity_timeout`
(`"${var.asg_health_check_grace_period * 1.5}m"` = **900m ≈ 15h** at the default). Harmless today, but the
description is wrong whichever reading you take.

## Other gotchas

- **`instance_refresh { triggers = ["tag"] }`** in website-pod — enabling the flag **triggers a rolling
  instance refresh**. Not a no-op apply. On a wiki that means real cycling; the EFS uploads volume and RDS
  are separate resources and survive, but expect a window.
- **Singleton blind spot.** The cohort-relative detector proposed in
  `loopproof/docs/inspector-exclusion-reconciliation-lag.md` alarms when an instance reports 0 findings while
  *same-AMI siblings* report findings. BookStack typically runs one instance, so that detector cannot see it.
  The observed failure mode — one prod jumphost stuck at 0 findings for 13h16m with no structural
  explanation — would be undetectable here. This is the main reason BookStack was deferred behind
  jumphost/openvpn; it does not block the change, but do not assume the detector covers it.
- **`propagate_at_launch` tags only at launch.** The ASG never re-applies tags to running instances, so it
  will not fight Puppet's deletion, and deleting a per-instance tag is not Terraform drift.

## Checklist

- [x] `main.tf` — bump website-pod to `6.5.0`, set `defer_inspector_findings_until_patched = true`
- [x] `datasources.tf` — `ec2:DeleteTags` statement
- [x] `make format` / `make lint`
- [x] `tests/test_module.py` — `verify_inspector_exclusion_tag_removed()` asserts both halves: the key is in
      `ASG.launch_tags`, and it is gone from the running instance. "The tag is gone" alone also passes if the
      flag was never set. Called after the existing `/var/run/puppet-done` wait — the tag drop is an exec in
      the catalog, so puppet-done implies it already ran, and `wait_for_bootstrap()` is not needed here.
      `requirements.txt` moved to `infrahouse-core ~= 1.3` for `ASG.launch_tags`. EC2 tag reads are eventually
      consistent and `EC2Instance` caches for 10s, so it polls at 15s rather than asserting once.
- [x] `terraform-docs` regen
- [ ] `bumpversion minor` + CHANGELOG — after the PR merges

## Verification after apply

Puppet log on a fresh instance shows one of:

- `removed InspectorEc2Exclusion from i-...` — the API call succeeded
- `could not remove ... (no ec2:DeleteTags?)` — the IAM statement is wrong or missing

The first message does **not** prove a tag was removed, since `delete-tags` ignores a missing key. Confirm
out of band:

```bash
aws ec2 describe-tags --filters Name=resource-id,Values=i-... --region us-west-1
```

website-pod sets `instance_metadata_tags = "enabled"`, so a future puppet-code change could read
`GET /latest/meta-data/tags/instance/InspectorEc2Exclusion` before deleting and log `removed` vs
`was not set` distinctly — no extra IAM. Worth doing before relying on this on a singleton.

Then expect findings **~1.5–2h of running time** after removal, not immediately. Measure with
`firstObservedAt`, never `lastScannedAt`.
