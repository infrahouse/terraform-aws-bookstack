resource "aws_secretsmanager_secret" "google_client" {
  description = "A JSON with Google OAuth Client ID"
  name_prefix = "google_client"
}

resource "aws_secretsmanager_secret_version" "google_client" {
  secret_id     = aws_secretsmanager_secret.google_client.id
  secret_string = <<EOT
{
  "web": {
    "client_id": "290217685136-foo.apps.googleusercontent.com",
    "project_id": "bookstack-424221",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_secret": "GOCSPX-very_secret",
    "redirect_uris": [
      "https://bookstack.ci-cd.infrahouse.com"
    ],
    "javascript_origins": [
      "https://bookstack.ci-cd.infrahouse.com"
    ]
  }
}
EOT
}
