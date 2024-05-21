resource "aws_secretsmanager_secret" "bookstack_app_key" {
  description             = "Bookstack application key, used for its encryption tasks."
  name                    = "bookstack_app_key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "bookstack_app_key" {
  secret_id     = aws_secretsmanager_secret.bookstack_app_key.id
  secret_string = "base64:${random_id.bookstack_app_key.b64_std}"
}

resource "random_id" "bookstack_app_key" {
  byte_length = 4 * 8
}

resource "aws_secretsmanager_secret" "db_user" {
  description             = "${var.service_name} database username and password"
  name_prefix             = "bookstack_db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_user" {
  secret_id = aws_secretsmanager_secret.db_user.id
  secret_string = jsonencode(
    {
      "user" : aws_db_instance.db.username
      "password" : aws_db_instance.db.password
    }
  )
}