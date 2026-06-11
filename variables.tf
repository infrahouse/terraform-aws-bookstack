variable "access_log_force_destroy" {
  description = "Destroy S3 bucket with access logs even if non-empty"
  type        = bool
  default     = false
}

variable "asg_ami" {
  description = "Image for EC2 instances"
  type        = string
  default     = null
}

variable "asg_health_check_grace_period" {
  description = "ASG will wait up to this number of minutes for instance to become healthy"
  type        = number
  default     = 600
}

variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = null
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = null
}

variable "backend_subnet_ids" {
  description = "List of subnet ids where the webserver and database instances will be created"
  type        = list(string)
}

variable "db_instance_type" {
  description = <<-EOF
    Instance type to run the database instances. Must support RDS Performance
    Insights, which the RDS module enables unconditionally (so db.t3.micro/small
    and db.t4g.micro/small are not valid choices).
  EOF
  type        = string
  default     = "db.t3.medium"
}

variable "dns_a_records" {
  description = <<-EOF
    A list of A records the BookStack application will be accessible at.
    E.g. ["wiki"] or ["bookstack", "docs"].
    By default, it will be [var.service_name].
  EOF
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "Name of environment."
  type        = string
}

variable "extra_files" {
  description = <<-EOT
    Additional files to create on an instance.

    ⚠️  WARNING: Large files increase userdata size. AWS has a 16KB limit.
    Consider storing large scripts in S3 and downloading them instead.
    Check the userdata_size_info output after applying to monitor usage.
  EOT
  type = list(
    object(
      {
        content     = string
        path        = string
        permissions = string
      }
    )
  )
  default = []
}

variable "extra_repos" {
  description = "Additional APT repositories to configure on an instance."
  type = map(
    object(
      {
        source = string
        key    = string
      }
    )
  )
  default = {}
}

# Example of the secret content
# {
#  "web": {
#    "client_id": "***.apps.googleusercontent.com",
#    "project_id": "bookstack-424221",
#    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
#    "token_uri": "https://oauth2.googleapis.com/token",
#    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
#    "client_secret": "***",
#    "redirect_uris": [
#      "https://bookstack.ci-cd.infrahouse.com"
#    ],
#    "javascript_origins": [
#      "https://bookstack.ci-cd.infrahouse.com"
#    ]
#  }
#}
variable "google_oauth_client_secret" {
  description = "AWS secretsmanager secret name with a Google Oauth 'client id' and 'client secret'."
  type        = string
}

variable "instance_type" {
  description = "Instance type to run the webserver instances"
  type        = string
  default     = "t3.micro"
}

variable "bookstack_prebuilt_package_url" {
  description = <<-EOF
    URL of a pre-built BookStack release tarball that already includes the composer
    vendor/ directory (single top-level dir, like the upstream source archive). It is
    downloaded to /var/tmp/bookstack.tar.gz before Puppet runs, which makes the Puppet
    profile's download_package and run_composer steps no-op (their `creates` guards are
    satisfied). This avoids running composer at boot, and with it the flaky Codeberg
    archive endpoint used by the ssddanbrown/htmldiff dependency.

    The version of this tarball MUST match the BookStack version configured in the Puppet
    profile (profile::bookstack::bookstack_package_url). Set to null to disable and use
    the stock flow (Puppet downloads source and runs composer install).
  EOF
  type        = string
  default     = "https://infrahouse-omnibus-cache.s3.us-west-1.amazonaws.com/bookstack/bookstack-v25.02.1-vendor.tar.gz"
}

variable "bookstack_prebuilt_package_sha256" {
  description = <<-EOF
    Expected SHA-256 of the bookstack_prebuilt_package_url artifact. The artifact is verified
    against this value before Puppet runs; a mismatch deletes the download and fails the bootstrap,
    so a tampered or replaced object cannot inject code into the application. Must be updated
    together with bookstack_prebuilt_package_url. Set to null to skip verification (not recommended).
  EOF
  type        = string
  default     = "9e31388ce60d740b344a52db2bbd806eb0bd92122ac4783c9f1b0e3d372980e3"
}

variable "access_log_replication_region" {
  description = "AWS region for cross-region replication of the ALB access log bucket. Must differ from the deployment region."
  type        = string
}

variable "key_pair_name" {
  description = "SSH keypair name to be deployed in EC2 instances"
  type        = string
  default     = null
}

variable "lb_subnet_ids" {
  description = "List of subnet ids where the load balancer will be created"
  type        = list(string)
}

variable "packages" {
  description = <<-EOT
    List of packages to install when the instance bootstraps.

    ⚠️  WARNING: Each package name increases userdata size. AWS has a 16KB limit.
    The module already includes mysql-client and nfs-common by default.
    Check the userdata_size_info output after applying to monitor usage.
  EOT
  type        = list(string)
  default     = []
}

variable "puppet_debug_logging" {
  description = "Enable debug logging if true."
  type        = bool
  default     = false
}

variable "puppet_hiera_config_path" {
  description = "Path to hiera configuration file."
  default     = "{root_directory}/environments/{environment}/hiera.yaml"
}

variable "puppet_module_path" {
  description = "Path to common puppet modules."
  default     = "{root_directory}/modules"
}

variable "puppet_root_directory" {
  description = "Path where the puppet code is hosted."
  default     = "/opt/puppet-code"
}

variable "service_name" {
  description = "DNS hostname for the service. It's also used to name some resources like EC2 instances."
  default     = "bookstack"
}

variable "smtp_credentials_secret" {
  description = <<-EOF
    AWS secret name with SMTP credentials.
    The secret must contain a JSON with user and password keys.
  EOF
  type        = string
  default     = null
}

variable "storage_encryption_key_arn" {
  description = <<-EOF
    KMS key ARN to encrypt RDS instance storage.
    If not provided, AWS managed key will be used.
    RDS encryption is always enabled.
  EOF
  type        = string
  default     = null
}

variable "efs_encryption_key_arn" {
  description = <<-EOF
    KMS key ARN to encrypt EFS file system.
    If not provided, AWS managed key will be used.
    EFS encryption is always enabled.
  EOF
  type        = string
  default     = null
}

variable "ssh_cidr_block" {
  description = "CIDR range that is allowed to SSH into the backend instances.  Format is a.b.c.d/<prefix>."
  type        = string
  default     = null
}

variable "ubuntu_codename" {
  description = "Ubuntu version to use for the BookStack instances"
  type        = string
  default     = "noble"
}

variable "zone_id" {
  description = "Domain name zone ID where the website will be available"
  type        = string
}

variable "sns_topic_alarm_arn" {
  description = "ARN of SNS topic for Cloudwatch alarms on base EC2 instance."
  type        = string
  default     = null
}

variable "extra_instance_profile_permissions" {
  description = <<-EOF
    A JSON with a permissions policy document.
    The policy will be attached to the ASG instance profile.
  EOF
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Specifies whether to enable deletion protection for the DB instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Specifies whether to skip the final snapshot when the DB instance is deleted."
  type        = bool
  default     = false
}

# Alarm and Monitoring Variables

variable "alarm_emails" {
  description = <<-EOF
    List of email addresses to receive alarm notifications for SES bounce rate, RDS issues, etc.
    AWS will send confirmation emails that must be accepted.
    At least one email is required.
  EOF
  type        = list(string)

  validation {
    condition     = length(var.alarm_emails) > 0
    error_message = "At least one email address must be provided for alarm notifications"
  }

  validation {
    condition = alltrue([
      for email in var.alarm_emails :
      can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", email))
    ])
    error_message = "All alarm_emails must be valid email addresses"
  }
}

variable "alarm_topic_arns" {
  description = <<-EOF
    List of existing SNS topic ARNs to send alarms to.
    Use for advanced integrations like PagerDuty, Slack, etc.
  EOF
  type        = list(string)
  default     = []
}

variable "sns_topic_name" {
  description = "Name for the SNS topic. If not provided, defaults to '<service_name>-alarms'"
  type        = string
  default     = null
}

variable "ses_bounce_rate_threshold" {
  description = "SES bounce rate percentage threshold (AWS recommends keeping below 5%)"
  type        = number
  default     = 0.05

  validation {
    condition     = var.ses_bounce_rate_threshold >= 0 && var.ses_bounce_rate_threshold <= 1
    error_message = "Bounce rate threshold must be between 0 and 1 (e.g., 0.05 for 5%)"
  }
}

variable "ses_complaint_rate_threshold" {
  description = "SES complaint rate percentage threshold (AWS recommends keeping below 0.1%)"
  type        = number
  default     = 0.001

  validation {
    condition     = var.ses_complaint_rate_threshold >= 0 && var.ses_complaint_rate_threshold <= 1
    error_message = "Complaint rate threshold must be between 0 and 1 (e.g., 0.001 for 0.1%)"
  }
}

variable "rds_performance_insights_retention_days" {
  description = <<-EOF
    Number of days to retain Performance Insights data.
    Valid values: 7 (free tier) or 731 (2 years, additional cost).
    Default is 7 days.
  EOF
  type        = number
  default     = 7

  validation {
    condition     = contains([7, 731], var.rds_performance_insights_retention_days)
    error_message = "Performance Insights retention must be 7 (free tier) or 731 days (2 years)"
  }
}

variable "smtp_key_rotation_days" {
  description = "Number of days between SMTP credential rotations"
  type        = number
  default     = 45

  validation {
    condition     = var.smtp_key_rotation_days >= 30 && var.smtp_key_rotation_days <= 90
    error_message = "Rotation period must be between 30 and 90 days per AWS best practices"
  }
}

variable "compress_userdata" {
  description = <<-EOT
    Compress userdata with gzip to reduce size and work around AWS 16KB limit.

    When enabled, userdata is gzip-compressed before being sent to EC2 instances.
    AWS automatically decompresses it before execution. This can reduce userdata
    size by 60-70%, allowing more packages, files, and configuration.

    Recommended: Enable if userdata_size_info shows approaching limit (>12KB).

    Requirements: gzip command must be available on the system running terraform.
  EOT
  type        = bool
  default     = false
}
