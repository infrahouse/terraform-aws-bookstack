variable "region" {
  description = "AWS region to deploy BookStack to"
  type        = string
  default     = "us-west-2"
}

variable "access_log_replication_region" {
  description = <<-EOT
    Region the ALB access log bucket is replicated to.
    Must be different from var.region.
  EOT
  type        = string
  default     = "us-east-1"
}

variable "lb_subnet_ids" {
  description = "Public subnet ids of an existing VPC where the load balancer is created"
  type        = list(string)
}

variable "backend_subnet_ids" {
  description = <<-EOT
    Private subnet ids of an existing VPC where the BookStack instances, the RDS
    instance and the EFS mount targets are created. The subnets need outbound
    internet access (NAT gateway) to install packages at boot.
  EOT
  type        = list(string)
}

variable "zone_id" {
  description = "Route 53 hosted zone id where the BookStack records are created"
  type        = string
}

variable "dns_role_arn" {
  description = "IAM role in the DNS account that is allowed to manage records in var.zone_id"
  type        = string
}

variable "alarm_emails" {
  description = <<-EOT
    Email addresses that receive alarm notifications. Every address gets an SNS
    subscription confirmation email that has to be confirmed.
  EOT
  type        = list(string)
}

variable "pagerduty_topic_arn" {
  description = "ARN of an existing SNS topic subscribed to by PagerDuty"
  type        = string
}

variable "google_oauth_client_json" {
  description = <<-EOT
    Contents of the Google OAuth client JSON downloaded from the Google Cloud
    Console. The redirect URIs and JavaScript origins configured in Google must
    cover every DNS name BookStack is served under.
  EOT
  type        = string
  sensitive   = true
}
