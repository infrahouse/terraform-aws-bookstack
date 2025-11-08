output "bookstack_urls" {
  description = "List of URLs where bookstack is available."
  value       = [for h in local.dns_a_records : "https://${h}.${data.aws_route53_zone.current.name}"]
}

output "bookstack_instance_role_arn" {
  description = "IAM role ARN assigned to bookstack EC2 instances."
  value       = local.ec2_role_arn
}

output "rds_instance_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.db.identifier
}

output "bookstack_load_balancer_arn" {
  description = "ARN of the load balancer for the BookStack website pod."
  value       = module.bookstack.load_balancer_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "smtp_credentials_next_rotation" {
  description = "Next SMTP credential rotation date (RFC3339 format)"
  value       = time_rotating.key_rotation.rotation_rfc3339
}

output "smtp_credentials_last_rotated" {
  description = "When SMTP credentials were last rotated (creation date of current key)"
  value       = aws_iam_access_key.emailer.create_date
}
