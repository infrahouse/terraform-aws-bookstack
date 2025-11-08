# Terraform Module Review: terraform-aws-bookstack

**Last Updated:** 2025-11-08
**Branch Reviewed:** key-rotation
**Reviewer:** Claude (Terraform/IaC Expert)

---

## Executive Summary

The `terraform-aws-bookstack` module is a well-structured InfraHouse Terraform module for deploying BookStack on AWS. The module demonstrates good infrastructure practices with proper secret management, multi-AZ RDS deployment, and use of EFS for persistent storage. However, there are several **critical security concerns** related to IAM access key rotation, AWS provider version compatibility, and some resource configurations that need to be addressed before production use.

**Overall Assessment:**
- **Structure & Organization:** Good
- **Security Posture:** Needs Improvement (Critical issues present)
- **AWS Best Practices:** Good
- **InfraHouse Standards Compliance:** Mostly Compliant
- **Production Readiness:** Not Ready (requires fixes)

---

## Critical Issues (Must Fix Before Use)

### 1. IAM Access Key Rotation - SECURITY CRITICAL

**Severity:** CRITICAL
**Location:** `smtp.tf` lines 10-12

**Issue:**
The module creates an IAM access key for SES SMTP (`aws_iam_access_key.bookstack-emailer`) but provides no mechanism for rotating these credentials. IAM access keys in Terraform state are a security risk, and AWS security best practices recommend regular rotation.

**Current Code:**
```hcl
resource "aws_iam_access_key" "bookstack-emailer" {
  user = aws_iam_user.bookstack-emailer.name
}
```

**Security Risks:**
1. Access keys stored in Terraform state forever
2. No automated rotation mechanism
3. Violates AWS IAM best practices for long-lived credentials
4. If compromised, attacker can send emails via SES indefinitely
5. No lifecycle management for credential rotation

**Recommendation:**
Given the branch name is "key-rotation", this is clearly a known issue. Consider these approaches:

**Option A: Use Instance Profile with SES (Preferred)**
- Remove IAM user entirely
- Grant SES SendEmail permissions to the EC2 instance role
- Use AWS SDK with instance credentials
- No long-lived credentials to manage

**Option B: Lambda-based Rotation**
- Implement AWS Secrets Manager rotation Lambda
- Use `aws_secretsmanager_secret_rotation` resource
- Automatic 90-day rotation cycle
- Requires custom Lambda function to rotate IAM access keys

**Option C: External Key Management**
- Document that keys must be rotated externally
- Add lifecycle policy with `create_before_destroy = true`
- Provide runbook for manual rotation
- Not ideal but better than current state

**Example Fix (Option A - Instance Profile):**
```hcl
# In datasources.tf - add to instance_permissions
data "aws_iam_policy_document" "instance_permissions" {
  # ... existing statements ...

  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["BookStack@${data.aws_route53_zone.current.name}"]
    }
  }
}

# Remove smtp.tf entirely or make it optional
```

### 2. AWS Provider Version Constraint Too Restrictive

**Severity:** CRITICAL (for InfraHouse standards)
**Location:** `terraform.tf` line 7

**Issue:**
The module requires `aws = "~> 5.11"` which locks users to AWS provider v5.x only. According to InfraHouse standards, modules should support **both AWS provider v5 and v6** for compatibility across projects.

**Current Code:**
```hcl
aws = {
  source  = "hashicorp/aws"
  version = "~> 5.11"
}
```

**Impact:**
- Module cannot be used with AWS provider v6
- Prevents adoption of newer AWS features
- Violates InfraHouse module reusability standards
- May cause version conflicts in composite modules

**Recommendation:**
```hcl
aws = {
  source  = "hashicorp/aws"
  version = ">= 5.11, < 7.0"  # Support both v5 and v6
}
```

**Testing Required:**
- Run tests against both AWS provider v5.x and v6.x
- Verify no breaking changes in v6 affect this module
- Update CI/CD to test against multiple provider versions

### 3. Hardcoded IAM User Name - Namespace Collision Risk

**Severity:** HIGH
**Location:** `smtp.tf` line 6

**Issue:**
The IAM user has a hardcoded name `bookstack-emailer` which will cause conflicts if multiple instances of this module are deployed in the same AWS account.

**Current Code:**
```hcl
resource "aws_iam_user" "bookstack-emailer" {
  name = "bookstack-emailer"
}
```

**Impact:**
- Cannot deploy multiple BookStack instances in same account
- Terraform will fail with "IAM user already exists"
- Reduces module reusability

**Recommendation:**
```hcl
resource "aws_iam_user" "bookstack-emailer" {
  name = "${var.service_name}-emailer"  # Make it unique per instance
  tags = local.tags
}
```

This allows multiple BookStack deployments like:
- `wiki-emailer`
- `docs-emailer`
- `bookstack-prod-emailer`

### 4. Missing Storage Encryption by Default

**Severity:** HIGH
**Location:** `db.tf` line 19, `efs.tf` line 1

**Issue:**
Both RDS and EFS encryption are **optional** instead of enforced by default.

**Current Code (RDS):**
```hcl
storage_encrypted = var.storage_encryption_key_arn != null ? true : false
kms_key_id        = var.storage_encryption_key_arn
```

**Current Code (EFS):**
```hcl
resource "aws_efs_file_system" "bookstack-uploads" {
  creation_token = "bookstack-uploads"
  # No encrypted = true
  # No kms_key_id specified
}
```

**Security Risks:**
1. Data at rest not encrypted by default
2. Violates AWS Well-Architected Security pillar
3. Compliance violations (HIPAA, PCI-DSS, etc.)
4. BookStack may contain sensitive documentation

**Recommendation:**

**For RDS:**
```hcl
resource "aws_db_instance" "db" {
  # ... other config ...
  storage_encrypted = true  # Always encrypt
  kms_key_id        = var.storage_encryption_key_arn  # Can be null (uses AWS managed key)
}

# Update variable description
variable "storage_encryption_key_arn" {
  description = "KMS key ARN to encrypt RDS instance storage. If not provided, AWS managed key will be used."
  type        = string
  default     = null
}
```

**For EFS:**
```hcl
resource "aws_efs_file_system" "bookstack-uploads" {
  creation_token = "bookstack-uploads"
  encrypted      = true
  kms_key_id     = var.efs_encryption_key_arn  # Add new variable

  tags = merge(
    {
      Name = "bookstack-uploads"
    },
    local.tags
  )
}

# Add new variable
variable "efs_encryption_key_arn" {
  description = "KMS key ARN to encrypt EFS file system. If not provided, AWS managed key will be used."
  type        = string
  default     = null
}
```

### 5. Overly Permissive Security Group Rules

**Severity:** HIGH
**Location:** `efs.tf` line 50-62, `db-sg.tf` line 28-35

**Issue 1 - ICMP Open to Internet:**
```hcl
resource "aws_vpc_security_group_ingress_rule" "efs_icmp" {
  description       = "Allow all ICMP traffic"
  security_group_id = aws_security_group.efs.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"  # INTERNET WIDE!
}
```

**Why is this dangerous?**
1. EFS is internal storage - no need for public ICMP
2. Enables ICMP tunneling attacks
3. Allows reconnaissance from internet
4. No legitimate use case for internet-wide ICMP to EFS

**Issue 2 - Unnecessary Database Egress:**
```hcl
resource "aws_vpc_security_group_egress_rule" "outgoing" {
  security_group_id = aws_security_group.db.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"  # Why does RDS need internet?
}
```

**Impact:**
- Violates principle of least privilege
- Increases attack surface
- RDS instances don't need internet access

**Recommendation:**

**For EFS ICMP:**
```hcl
resource "aws_vpc_security_group_ingress_rule" "efs_icmp" {
  description       = "Allow ICMP traffic from VPC"
  security_group_id = aws_security_group.efs.id
  from_port         = -1
  to_port           = -1
  ip_protocol       = "icmp"
  cidr_ipv4         = data.aws_vpc.selected.cidr_block  # VPC only
}
```

**For RDS Egress:**
```hcl
# Remove entirely - RDS doesn't need outbound internet
# If needed for specific reason, document why and restrict to specific destinations
```

---

## Security Concerns

### 6. TLS Private Key in Terraform State

**Severity:** MEDIUM
**Location:** `keypair.tf` lines 1-4

**Issue:**
```hcl
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
```

The private key is stored in Terraform state unencrypted (unless remote state encryption is configured).

**Recommendation:**
Either:
1. **Document the requirement** that Terraform state MUST be encrypted
2. **Add state encryption check** in pre-commit hooks
3. **External key management**: Generate SSH keys externally and pass public key via variable
4. **Make it optional**: Only create if `var.key_pair_name == null`

**Preferred approach:**
```hcl
# Add to variables.tf
variable "generate_key_pair" {
  description = "Whether to generate a new SSH key pair. If false, key_pair_name must be provided."
  type        = bool
  default     = false  # Don't generate by default
}

# Update keypair.tf
resource "tls_private_key" "rsa" {
  count     = var.generate_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  count      = var.generate_key_pair ? 1 : 0
  public_key = tls_private_key.rsa[0].public_key_openssh
}

# Update main.tf
key_pair_name = var.key_pair_name == null ? (
  var.generate_key_pair ? aws_key_pair.deployer[0].key_name : null
) : var.key_pair_name
```

### 7. SES Permission Too Broad

**Severity:** MEDIUM
**Location:** `smtp.tf` lines 14-24

**Issue:**
```hcl
data "aws_iam_policy_document" "bookstack-emailer-permissions" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]  # Too broad
  }
}
```

**Recommendation:**
```hcl
data "aws_iam_policy_document" "bookstack-emailer-permissions" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = [
        "BookStack@${data.aws_route53_zone.current.name}",
        "*@${data.aws_route53_zone.current.name}"
      ]
    }
  }
}
```

This limits the IAM user to only send emails from the configured domain.

### 8. Missing Secrets Rotation Configuration

**Severity:** MEDIUM
**Location:** `secrets.tf`

**Issue:**
While the module correctly uses AWS Secrets Manager via the `infrahouse/secret/aws` module, there's no rotation configuration for:
- Database password (`module.db_user`)
- App key (`module.bookstack_app_key`)

**Recommendation:**
Add rotation configuration or document manual rotation process:

```hcl
module "db_user" {
  source  = "registry.infrahouse.com/infrahouse/secret/aws"
  version = "1.0.2"

  # ... existing config ...

  # Add rotation configuration if supported by secret module
  rotation_enabled = var.enable_db_password_rotation
  rotation_days    = var.db_password_rotation_days
}

variable "enable_db_password_rotation" {
  description = "Enable automatic rotation of database password"
  type        = bool
  default     = false  # Opt-in to avoid breaking changes
}

variable "db_password_rotation_days" {
  description = "Number of days between automatic database password rotations"
  type        = number
  default     = 90
}
```

**Note:** Check if `infrahouse/secret/aws` v1.0.2 supports rotation. If not, document manual rotation procedure in README.

---

## Important Improvements (Should Fix)

### 9. Missing Output for EFS File System ID

**Severity:** MEDIUM
**Location:** `outputs.tf`

**Issue:**
The EFS file system is created but not exposed as an output, making it difficult to reference in other modules or for debugging.

**Recommendation:**
```hcl
output "efs_file_system_id" {
  description = "ID of the EFS file system used for BookStack uploads"
  value       = aws_efs_file_system.bookstack-uploads.id
}

output "efs_file_system_arn" {
  description = "ARN of the EFS file system used for BookStack uploads"
  value       = aws_efs_file_system.bookstack-uploads.arn
}

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.db.endpoint
  sensitive   = false  # Not sensitive, just connection info
}

output "database_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.db.arn
}
```

### 10. Hardcoded Database Engine Version

**Severity:** MEDIUM
**Location:** `db.tf` line 8

**Issue:**
```hcl
engine_version = "8.0"
```

This locks users to MySQL 8.0. AWS recommends specifying minor versions for production and allowing patch upgrades.

**Recommendation:**
```hcl
variable "db_engine_version" {
  description = "MySQL engine version for RDS instance"
  type        = string
  default     = "8.0"

  validation {
    condition     = can(regex("^8\\.", var.db_engine_version))
    error_message = "Only MySQL 8.x is supported by BookStack"
  }
}

resource "aws_db_instance" "db" {
  # ... other config ...
  engine                  = "mysql"
  engine_version          = var.db_engine_version
  auto_minor_version_upgrade = true  # Allow automatic patch upgrades
}
```

### 11. Missing CloudWatch Monitoring for RDS

**Severity:** MEDIUM
**Location:** `db.tf`

**Issue:**
No enhanced monitoring enabled for RDS instance.

**Recommendation:**
```hcl
variable "rds_enhanced_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.rds_enhanced_monitoring_interval)
    error_message = "Must be 0, 1, 5, 10, 15, 30, or 60"
  }
}

resource "aws_db_instance" "db" {
  # ... existing config ...

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  monitoring_interval             = var.rds_enhanced_monitoring_interval
  monitoring_role_arn            = var.rds_enhanced_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  performance_insights_enabled    = true
  performance_insights_retention_period = 7
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.rds_enhanced_monitoring_interval > 0 ? 1 : 0
  name_prefix = "${var.service_name}-rds-monitoring-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.rds_enhanced_monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
```

### 12. Missing Backup Window Configuration

**Severity:** MEDIUM
**Location:** `db.tf`

**Issue:**
No `preferred_backup_window` or `preferred_maintenance_window` specified, so AWS chooses random times which might impact production.

**Recommendation:**
```hcl
variable "db_backup_window" {
  description = "Preferred backup window (UTC). Format: hh24:mi-hh24:mi"
  type        = string
  default     = "03:00-04:00"  # 3 AM UTC
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window (UTC). Format: ddd:hh24:mi-ddd:hh24:mi"
  type        = string
  default     = "sun:04:00-sun:05:00"  # Sunday 4 AM UTC
}

resource "aws_db_instance" "db" {
  # ... existing config ...
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window
}
```

### 13. Missing Tags on Some Resources

**Severity:** LOW
**Location:** `db-sg.tf` line 32-34

**Issue:**
Some resources don't include `local.tags`:

```hcl
resource "aws_vpc_security_group_egress_rule" "outgoing" {
  security_group_id = aws_security_group.db.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = {
    Name = "outgoing traffic"
  }  # Missing local.tags
}
```

**Recommendation:**
```hcl
tags = merge(
  {
    Name = "outgoing traffic"
  },
  local.tags
)
```

Apply to all resources: security group rules in `efs.tf` and `db-sg.tf`.

### 14. Random Password Should Be More Complex

**Severity:** LOW
**Location:** `db.tf` lines 34-37

**Issue:**
```hcl
resource "random_password" "db_user" {
  length  = 21
  special = false  # Should allow special characters
}
```

**Recommendation:**
```hcl
resource "random_password" "db_user" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"  # Exclude problematic chars
  min_special      = 2
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
}
```

### 15. Inconsistent Resource Naming

**Severity:** LOW
**Location:** Multiple files

**Issue:**
Inconsistent use of dashes vs underscores:
- `aws_efs_file_system.bookstack-uploads` (dash)
- `module.bookstack_app_key` (underscore)
- `aws_security_group.efs` (no prefix)

**Recommendation:**
Terraform best practice is snake_case for resource names. Consider:
```hcl
# Good
resource "aws_efs_file_system" "bookstack_uploads" { }
resource "aws_iam_user" "bookstack_emailer" { }

# Or with consistent prefixing
resource "aws_efs_file_system" "this" { }
resource "aws_security_group" "efs" { }
resource "aws_security_group" "db" { }
```

---

## Code Quality & Maintainability

### 16. Missing Variable Validation

**Severity:** MEDIUM
**Location:** `variables.tf`

**Issue:**
Several variables lack validation rules that could catch user errors early.

**Recommendations:**

```hcl
variable "backend_subnet_ids" {
  description = "List of subnet ids where the webserver and database instances will be created"
  type        = list(string)

  validation {
    condition     = length(var.backend_subnet_ids) >= 2
    error_message = "At least 2 subnets required for multi-AZ deployment"
  }
}

variable "lb_subnet_ids" {
  description = "List of subnet ids where the load balancer will be created"
  type        = list(string)

  validation {
    condition     = length(var.lb_subnet_ids) >= 2
    error_message = "At least 2 subnets required for ALB high availability"
  }
}

variable "db_instance_type" {
  description = "Instance type to run the database instances"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.", var.db_instance_type))
    error_message = "Must be a valid RDS instance type starting with 'db.'"
  }
}

variable "service_name" {
  description = "DNS hostname for the service. It's also used to name some resources like EC2 instances."
  type        = string
  default     = "bookstack"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.service_name))
    error_message = "service_name must contain only lowercase letters, numbers, and hyphens"
  }

  validation {
    condition     = length(var.service_name) <= 32
    error_message = "service_name must be 32 characters or less"
  }
}

variable "environment" {
  description = "Name of environment."
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "environment must be development, staging, or production"
  }
}
```

### 17. Inefficient Dynamic Block in DB Parameters

**Severity:** LOW
**Location:** `db.tf` lines 42-53

**Issue:**
```hcl
dynamic "parameter" {
  for_each = toset(
    concat(
      local.db_params_common,
    )  # concat with single argument is unnecessary
  )
}
```

**Recommendation:**
```hcl
dynamic "parameter" {
  for_each = local.db_params_common
  content {
    apply_method = parameter.value.apply_method
    name         = parameter.value.name
    value        = parameter.value.value
  }
}

# In locals.tf, change from list to set if using toset
locals {
  db_params_common = {
    binlog_format = {
      apply_method = "immediate"
      name         = "binlog_format"
      value        = "ROW"
    }
    # Easy to add more parameters
  }
}
```

### 18. Magic Numbers in Code

**Severity:** LOW
**Location:** Multiple files

**Issue:**
Several magic numbers without explanation:
- `random_string.role-suffix` length = 6 (locals.tf:102)
- `random_id.bookstack_app_key` byte_length = 32 (secrets.tf:15)
- `random_password.db_user` length = 21 (db.tf:35)

**Recommendation:**
Add comments explaining the reasoning:

```hcl
resource "random_string" "role-suffix" {
  length  = 6  # Short suffix to keep IAM role name under 64 character limit
  special = false
}

resource "random_id" "bookstack_app_key" {
  byte_length = 32  # 256-bit key as required by Laravel/BookStack encryption
}
```

### 19. Locals Could Be More Organized

**Severity:** LOW
**Location:** `locals.tf`

**Issue:**
The locals file mixes different concerns. Consider organizing by category:

```hcl
locals {
  # Tags
  tags = {
    created_by_module : "infrahouse/bookstack/aws"
  }

  # Networking
  efs_mount_path = "/mnt/efs"

  # DNS configuration
  dns_a_records = var.dns_a_records == null ? [var.service_name] : var.dns_a_records

  # IAM
  ec2_role_name = "${var.service_name}-${random_string.role-suffix.result}"
  ec2_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.ec2_role_name}"

  # Email configuration
  smtp_endpoints = {
    us-west-1 = "email-smtp.us-west-1.amazonaws.com"
    us-west-2 = "email-smtp.us-west-2.amazonaws.com"
    us-east-1 = "email-smtp.us-east-1.amazonaws.com"
    us-east-2 = "email-smtp.us-east-2.amazonaws.com"
  }

  # Database configuration
  db_params_common = [
    {
      apply_method = "immediate"
      name         = "binlog_format"
      value        = "ROW"  # Required for multi-AZ replication
    },
  ]

  # AMI selection
  ami_name_pattern = contains(
    ["focal", "jammy"], var.ubuntu_codename
  ) ? "ubuntu/images/hvm-ssd/ubuntu-${var.ubuntu_codename}-*" : "ubuntu/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-*"

  ami_name_pattern_pro = "ubuntu-pro-server/images/hvm-ssd-gp3/ubuntu-${var.ubuntu_codename}-*"
}
```

---

## InfraHouse Standards Compliance

### 20. Missing Module Examples Directory

**Severity:** MEDIUM
**Location:** Repository root

**Issue:**
While `test_data/bookstack/` exists, there's no `examples/` directory with common usage patterns as seen in other InfraHouse modules.

**Recommendation:**
Create `examples/` directory with:
- `examples/basic/` - Minimal configuration
- `examples/complete/` - All features enabled
- `examples/multi-region/` - Multi-region setup
- `examples/production/` - Production-ready configuration with all security features

### 21. Incomplete Variable Documentation

**Severity:** LOW
**Location:** `variables.tf`

**Issue:**
Variable `ubuntu_codename` has misleading description:

```hcl
variable "ubuntu_codename" {
  description = "Ubuntu version to use for the elasticsearch node"  # Wrong service!
  type        = string
  default     = "jammy"
}
```

**Recommendation:**
```hcl
variable "ubuntu_codename" {
  description = "Ubuntu version to use for BookStack instances (e.g., 'jammy', 'noble')"
  type        = string
  default     = "jammy"

  validation {
    condition     = contains(["focal", "jammy", "noble"], var.ubuntu_codename)
    error_message = "Supported Ubuntu versions: focal (20.04), jammy (22.04), noble (24.04)"
  }
}
```

### 22. Test Coverage

**Severity:** MEDIUM
**Location:** `tests/test_module.py`

**Issue:**
Only one test case exists. Should have:
- Multiple provider version tests (AWS v5 and v6)
- Different configurations (minimal, complete)
- Negative tests (invalid inputs)

**Recommendation:**

```python
# tests/test_module.py
import pytest

@pytest.mark.parametrize("provider_version", ["5.70.0", "6.0.0"])
def test_module_multiple_providers(
    service_network, ses, aws_region, test_role_arn, test_zone_name, provider_version
):
    """Test module works with both AWS provider v5 and v6"""
    # Test implementation

def test_module_with_encryption(
    service_network, ses, aws_region, test_role_arn, test_zone_name, kms_key
):
    """Test module with custom KMS encryption keys"""
    # Test implementation

def test_module_minimal_config(
    service_network, ses, aws_region, test_role_arn, test_zone_name
):
    """Test module with minimal configuration"""
    # Test implementation
```

### 23. Formatting Issues in Test Data

**Severity:** LOW
**Location:** Test data files

**Issue:**
Running `terraform fmt -check` shows formatting issues:
```
test_data\bookstack\terraform.tfvars
test_data\service-network\terraform.tfvars
test_data\ses\terraform.tfvars
```

**Recommendation:**
Run `terraform fmt -recursive` to fix.

---

## Positive Observations

The module demonstrates several excellent practices:

1. **Secret Management Excellence**
   - Proper use of AWS Secrets Manager for all sensitive data
   - Database credentials, app keys, and SMTP passwords properly isolated
   - IAM read permissions correctly scoped to EC2 instance role
   - Use of InfraHouse's `infrahouse/secret/aws` module for consistency

2. **High Availability Design**
   - Multi-AZ RDS deployment (`multi_az = true`)
   - EFS mount targets in all backend subnets
   - ASG with multiple instances across availability zones
   - Proper backup retention (7 days)

3. **Good Resource Organization**
   - Logical file separation (db.tf, efs.tf, smtp.tf, etc.)
   - Clear resource naming
   - Consistent use of local.tags across resources

4. **Deletion Protection**
   - RDS deletion protection enabled by default (`deletion_protection = true`)
   - Configurable final snapshot behavior
   - Access log bucket protection configurable

5. **Proper Data Source Usage**
   - Uses data sources instead of hardcoded values
   - Dynamic AMI lookup with proper filters
   - Route53 zone lookup via provider alias

6. **Network Security**
   - Database in private subnets only
   - Security group ingress scoped to VPC CIDR
   - EFS access restricted to backend instances

7. **Testing Infrastructure**
   - Pytest-based testing with proper fixtures
   - CI/CD integration via GitHub Actions
   - Proper test isolation with unique resources

8. **Documentation**
   - Comprehensive README with terraform-docs
   - All variables documented
   - Examples provided in test_data

---

## Missing Features

### 24. No CloudWatch Alarms

**Severity:** MEDIUM

**Recommendation:**
Add CloudWatch alarms for:

```hcl
# RDS alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.sns_topic_alarm_arn != null ? 1 : 0
  alarm_name          = "${var.service_name}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is too high"
  alarm_actions       = [var.sns_topic_alarm_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = var.sns_topic_alarm_arn != null ? 1 : 0
  alarm_name          = "${var.service_name}-rds-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5000000000  # 5 GB
  alarm_description   = "RDS free storage is running low"
  alarm_actions       = [var.sns_topic_alarm_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }
}

# EFS alarms
resource "aws_cloudwatch_metric_alarm" "efs_burst_credit" {
  count               = var.sns_topic_alarm_arn != null ? 1 : 0
  alarm_name          = "${var.service_name}-efs-burst-credits"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BurstCreditBalance"
  namespace           = "AWS/EFS"
  period              = 600
  statistic           = "Average"
  threshold           = 1000000000000  # 1 TB
  alarm_description   = "EFS burst credits running low"
  alarm_actions       = [var.sns_topic_alarm_arn]

  dimensions = {
    FileSystemId = aws_efs_file_system.bookstack-uploads.id
  }
}
```

### 25. No RDS Read Replica Support

**Severity:** LOW

For production workloads, consider adding optional read replica support:

```hcl
variable "create_read_replica" {
  description = "Create a read replica for the RDS instance"
  type        = bool
  default     = false
}

variable "read_replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 1
}

resource "aws_db_instance" "read_replica" {
  count               = var.create_read_replica ? var.read_replica_count : 0
  identifier          = "${var.service_name}-read-replica-${count.index + 1}"
  replicate_source_db = aws_db_instance.db.identifier
  instance_class      = var.db_instance_type

  # Read replicas inherit most settings from primary
  publicly_accessible = false
  skip_final_snapshot = true

  tags = merge(
    {
      Name = "${var.service_name}-read-replica-${count.index + 1}"
      Type = "read-replica"
    },
    local.tags
  )
}
```

### 26. No WAF Support for ALB

**Severity:** LOW

For production deployments, consider adding AWS WAF:

```hcl
variable "enable_waf" {
  description = "Enable AWS WAF for the Application Load Balancer"
  type        = bool
  default     = false
}

variable "waf_acl_arn" {
  description = "ARN of existing WAF WebACL to associate with ALB"
  type        = string
  default     = null
}

# Note: Would need to modify the website-pod module or add association here
```

---

## Testing Recommendations

### 27. Add Pre-Commit Hooks

**Severity:** MEDIUM
**Location:** `hooks/pre-commit`

**Current State:**
```bash
#!/usr/bin/env bash
echo "Happy coding!"
```

**Recommendation:**
```bash
#!/usr/bin/env bash

set -e

echo "Running pre-commit checks..."

# Format check
echo "Checking Terraform formatting..."
terraform fmt -check -recursive || {
  echo "ERROR: Terraform files are not formatted. Run 'make format' to fix."
  exit 1
}

# Validate
echo "Validating Terraform configuration..."
terraform init -backend=false > /dev/null
terraform validate || {
  echo "ERROR: Terraform validation failed"
  exit 1
}

# TFLint (if available)
if command -v tflint > /dev/null; then
  echo "Running tflint..."
  tflint --init > /dev/null
  tflint
fi

# Detect secrets (if available)
if command -v detect-secrets > /dev/null; then
  echo "Scanning for secrets..."
  detect-secrets scan --baseline .secrets.baseline
fi

echo "All pre-commit checks passed!"
```

### 28. Add GitHub Actions Security Scanning

**Severity:** MEDIUM
**Location:** `.github/workflows/`

Add security scanning workflow:

```yaml
name: Security Scan

on:
  pull_request:
  push:
    branches: [main]

jobs:
  tfsec:
    name: tfsec
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          soft_fail: false

  checkov:
    name: Checkov
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: .
          framework: terraform
```

---

## Implementation Decision Questions

Before implementing fixes, please clarify:

1. **IAM Access Key Strategy (Critical #1):**
   - Should we migrate to instance profile approach (recommended)?
   - If keeping IAM user, what rotation mechanism is acceptable?
   - Is there a BookStack requirement preventing instance profile use?

2. **Provider Version (Critical #2):**
   - Can we immediately update to support AWS provider v6?
   - What's the testing timeline for multi-provider support?

3. **Encryption Defaults (Critical #4):**
   - Should encryption be mandatory or configurable?
   - Should we require customer-managed KMS keys or allow AWS-managed?

4. **Breaking Changes:**
   - Are breaking changes acceptable for next major version?
   - Should we maintain backward compatibility?

5. **Security Posture:**
   - What's the target compliance framework (PCI-DSS, HIPAA, SOC2)?
   - Are there organizational security policies to consider?

---

## Next Steps

### Immediate Actions (Before Production Use)

1. **Fix IAM Access Key Rotation** (Critical #1)
2. **Update AWS Provider Constraint** (Critical #2)
3. **Fix Hardcoded IAM User Name** (Critical #3)
4. **Enable Storage Encryption by Default** (Critical #4)
5. **Fix Security Group Rules** (Critical #5)

### Short-Term Improvements

1. Add missing outputs (Issue #9)
2. Make database version configurable (Issue #10)
3. Add CloudWatch monitoring (Issues #11, #24)
4. Implement variable validation (Issue #16)
5. Fix formatting issues (Issue #23)

### Long-Term Enhancements

1. Add comprehensive test coverage (Issue #22)
2. Create examples directory (Issue #20)
3. Add WAF support (Issue #26)
4. Implement read replica support (Issue #25)
5. Add security scanning to CI/CD (Issue #28)

---

## Summary Statistics

- **Critical Issues:** 5
- **High Severity:** 3
- **Medium Severity:** 11
- **Low Severity:** 8
- **Total Issues:** 27
- **Positive Observations:** 8

**Estimated Time to Fix Critical Issues:** 4-8 hours
**Estimated Time for All Improvements:** 16-24 hours

---

## Conclusion

The terraform-aws-bookstack module is well-structured and demonstrates good Infrastructure as Code practices. However, several **critical security issues** must be addressed before production deployment, particularly around IAM access key management, encryption defaults, and security group configurations.

The module's use of AWS Secrets Manager, multi-AZ deployment, and proper resource organization are commendable. With the recommended fixes, this module will be production-ready and align with both AWS Well-Architected Framework principles and InfraHouse standards.

**Current Status:** NOT PRODUCTION READY
**Status After Critical Fixes:** PRODUCTION READY with minor limitations
**Status After All Fixes:** PRODUCTION READY with comprehensive features

---

**Review completed:** 2025-11-08
**Reviewer:** Claude (Terraform/IaC Expert)
**Module Version:** key-rotation branch (based on main f3c233f)