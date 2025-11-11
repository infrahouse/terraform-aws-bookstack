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

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group for BookStack instances"
  value       = module.bookstack.asg_name
}

output "database_address" {
  description = "Address of the RDS database instance"
  value       = aws_db_instance.db.address
}

output "database_port" {
  description = "Port of the RDS database instance"
  value       = aws_db_instance.db.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.db.db_name
}

output "database_secret_name" {
  description = "Name of the secret containing database credentials"
  value       = module.db_user.secret_name
}

output "userdata_size_info" {
  description = <<-EOT
    Userdata size information for launch template validation.
    AWS limit is 16KB (16384 bytes) after base64 encoding.
    If size exceeds limit, EC2 launch will fail.
  EOT
  value = {
    compression_enabled = var.compress_userdata
    raw_bytes           = length(module.bookstack-userdata.userdata)
    base64_bytes        = ceil(length(module.bookstack-userdata.userdata) * 4 / 3)
    base64_kb           = format("%.2f", ceil(length(module.bookstack-userdata.userdata) * 4 / 3) / 1024)
    aws_limit_kb        = "16.00"
    remaining_bytes     = 16384 - ceil(length(module.bookstack-userdata.userdata) * 4 / 3)
    utilization_pct     = format("%.1f%%", (ceil(length(module.bookstack-userdata.userdata) * 4 / 3) / 16384) * 100)
    status = (
      ceil(length(module.bookstack-userdata.userdata) * 4 / 3) > 16384 ? "❌ EXCEEDS LIMIT" :
      ceil(length(module.bookstack-userdata.userdata) * 4 / 3) > 14336 ? "⚠️  APPROACHING LIMIT" :
      "✓ OK"
    )
    recommendation = (
      ceil(length(module.bookstack-userdata.userdata) * 4 / 3) > 16384 ? "CRITICAL: Enable compression (var.compress_userdata = true) or reduce userdata size" :
      ceil(length(module.bookstack-userdata.userdata) * 4 / 3) > 14336 && !var.compress_userdata ? "Consider enabling var.compress_userdata = true to compress userdata" :
      ceil(length(module.bookstack-userdata.userdata) * 4 / 3) > 14336 ? "Approaching limit even with compression - reduce extra_files or packages" :
      "Size is within safe limits"
    )
  }
}
