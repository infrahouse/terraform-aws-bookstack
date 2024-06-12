module "bookstack_app_key" {
  source             = "registry.infrahouse.com/infrahouse/secret/aws"
  version            = "0.5.0"
  secret_description = "Bookstack application key, used for its encryption tasks."
  secret_name        = "bookstack_app_key"
  secret_value       = "base64:${random_id.bookstack_app_key.b64_std}"
  tags               = local.tags
  readers = [
    local.ec2_role_arn
  ]
}

resource "random_id" "bookstack_app_key" {
  byte_length = 4 * 8
}

module "db_user" {
  source             = "registry.infrahouse.com/infrahouse/secret/aws"
  version            = "0.5.0"
  secret_description = "${var.service_name} database username and password"
  secret_name_prefix = "bookstack_db"
  secret_value = jsonencode(
    {
      "user" : aws_db_instance.db.username
      "password" : aws_db_instance.db.password
    }
  )
  tags = local.tags
  readers = [
    local.ec2_role_arn
  ]
}

module "ses_smtp_password" {
  source             = "registry.infrahouse.com/infrahouse/secret/aws"
  version            = "0.5.0"
  secret_description = "${var.service_name} SES SMTP password"
  secret_name_prefix = "${var.service_name}_ses_smtp_password"
  secret_value       = aws_iam_access_key.bookstack-emailer.ses_smtp_password_v4
  tags               = local.tags
  readers = [
    local.ec2_role_arn
  ]
}

data "aws_secretsmanager_secret" "google_client" {
  name = var.google_oauth_client_secret
}
