locals {
  tags = {
    created_by_module : "infrahouse/bookstack/aws"
  }
  smtp_endpoints = {
    us-west-1 : "email-smtp.us-west-1.amazonaws.com"
    us-west-2 : "email-smtp.us-west-2.amazonaws.com"
    us-east-1 : "email-smtp.us-east-1.amazonaws.com"
    us-east-2 : "email-smtp.us-east-2.amazonaws.com"
  }
  dns_a_records = var.dns_a_records == null ? [var.service_name] : var.dns_a_records
  ec2_role_name = "${var.service_name}-${random_string.role-suffix.result}"
  ec2_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.ec2_role_name}"
}
