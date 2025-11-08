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
  description = "Instance type to run the database instances"
  type        = string
  default     = "db.t3.micro"
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
  default     = "development"
}

variable "extra_files" {
  description = "Additional files to create on an instance."
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

variable "internet_gateway_id" { # tflint-ignore: terraform_unused_declarations
  description = "Not used, but AWS Internet Gateway must be present. Ensure by passing its id."
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
  description = "List of packages to install when the instances bootstraps."
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
  description = "Ubuntu version to use for the elasticsearch node"
  type        = string
  default     = "jammy"
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

variable "enable_ses_alarms" {
  description = "Enable CloudWatch alarms for SES bounce/complaint rates"
  type        = bool
  default     = true
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

variable "enable_rds_alarms" {
  description = "Enable CloudWatch alarms for RDS metrics"
  type        = bool
  default     = true
}

variable "rds_cpu_threshold" {
  description = <<-EOF
    RDS CPU utilization percentage threshold for alarms.
    Default is 80% - alarm triggers when CPU exceeds this value.
  EOF
  type        = number
  default     = 80

  validation {
    condition     = var.rds_cpu_threshold >= 0 && var.rds_cpu_threshold <= 100
    error_message = "CPU threshold must be between 0 and 100"
  }
}

variable "rds_storage_threshold_gb" {
  description = <<-EOF
    RDS free storage space threshold in gigabytes (GB) for alarms.
    Default is 5GB - alarm triggers when free space drops below this value.
  EOF
  type        = number
  default     = 5

  validation {
    condition     = var.rds_storage_threshold_gb >= 0
    error_message = "Storage threshold must be a positive number (in GB)"
  }
}

variable "rds_connections_threshold" {
  description = <<-EOF
    RDS database connections threshold for alarms.
    Default is 80 - alarm triggers when connection count exceeds this value.
    Adjust based on your instance type's max_connections setting.
  EOF
  type        = number
  default     = 80

  validation {
    condition     = var.rds_connections_threshold >= 0
    error_message = "Connections threshold must be a positive number"
  }
}

variable "enable_rds_cloudwatch_logs" {
  description = <<-EOF
    Enable CloudWatch logs export for RDS.
    Exports error, general, and slow query logs to CloudWatch.
  EOF
  type        = bool
  default     = true
}

variable "rds_cloudwatch_logs_retention_days" {
  description = <<-EOF
    Number of days to retain RDS CloudWatch logs.
    Default is 365 days (1 year). Set to 0 for never expire.
    Valid values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
  EOF
  type        = number
  default     = 365

  validation {
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
      1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.rds_cloudwatch_logs_retention_days)
    error_message = "Retention days must be one of AWS's allowed values: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653"
  }
}

variable "enable_rds_performance_insights" {
  description = <<-EOF
    Enable Performance Insights for RDS.
    Provides advanced database performance monitoring and analysis.
  EOF
  type        = bool
  default     = true
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
