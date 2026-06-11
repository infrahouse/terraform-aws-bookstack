module "bookstack_app_key" {
  source  = "registry.infrahouse.com/infrahouse/secret/aws"
  version = "1.3.0"

  service_name       = var.service_name
  environment        = var.environment
  secret_description = "Bookstack application key, used for its encryption tasks."
  secret_name_prefix = "bookstack_app_key"
  secret_value       = "base64:${random_id.bookstack_app_key.b64_std}"
  tags               = local.tags
  readers = [
    local.ec2_role_arn
  ]
}

resource "random_id" "bookstack_app_key" {
  byte_length = 4 * 8
}

module "ses_smtp_password" {
  source  = "registry.infrahouse.com/infrahouse/secret/aws"
  version = "1.3.0"

  service_name       = var.service_name
  environment        = var.environment
  secret_description = "${var.service_name} SES SMTP password"
  secret_name_prefix = "${var.service_name}_ses_smtp_password"
  secret_value       = aws_iam_access_key.emailer.ses_smtp_password_v4
  tags               = local.tags
  readers = [
    local.ec2_role_arn
  ]
}

data "aws_secretsmanager_secret" "google_client" {
  name = var.google_oauth_client_secret
}
