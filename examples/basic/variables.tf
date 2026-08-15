variable "google_oauth_client_json" {
  description = <<-EOT
    Contents of the Google OAuth client JSON downloaded from the Google Cloud
    Console. BookStack reads the "web" object of this document to authenticate
    users. The redirect URIs and JavaScript origins configured in Google must
    cover the BookStack URL, e.g. https://bookstack.example.com.

    Pass it from a file outside of version control:
    terraform apply -var="google_oauth_client_json=$(cat ~/google_client.json)"
  EOT
  type        = string
  sensitive   = true
}
