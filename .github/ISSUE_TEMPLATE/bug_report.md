---
name: Bug report
about: Report a problem with the module
title: ''
labels: bug
assignees: ''
---

## Describe the Bug

A clear and concise description of what the bug is.

## To Reproduce

Module configuration that triggers the problem:

```hcl
module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "x.y.z"
  # ...
}
```

Steps:

1. Run `terraform apply`
2. ...

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened. Include the Terraform error output if any:

```
paste output here
```

## Environment

- Module version:
- Terraform version (`terraform version`):
- AWS provider version:

## Additional Context

Anything else that helps: the `userdata_size_info` output, cloud-init or Puppet
logs from an instance (`/var/log/cloud-init-output.log`), CloudWatch alarms that
fired, etc.
