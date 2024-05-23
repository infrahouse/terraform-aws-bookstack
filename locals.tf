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
}
