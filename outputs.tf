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
  value       = module.rds.db_instance_id
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
  value       = module.rds.db_instance_address
}

output "database_port" {
  description = "Port of the RDS database instance"
  value       = module.rds.db_instance_port
}

output "database_name" {
  description = "Name of the database"
  value       = module.rds.db_instance_name
}

output "database_secret_name" {
  description = "Name of the secret containing the database master credentials"
  value       = data.aws_secretsmanager_secret.master.name
}

output "userdata_size_info" {
  description = <<-EOT
    Userdata size information for launch template validation.
    EC2 limits user data to 16384 bytes of decoded payload; the base64 string
    that carries it is ~4/3 longer and is not what the limit applies to.
    Exceeding it fails CreateLaunchTemplate with InvalidUserData.Malformed.
  EOT
  value = {
    compression_enabled = var.compress_userdata
    base64_chars        = local.userdata_b64_chars
    payload_bytes       = local.userdata_bytes
    payload_kb          = format("%.2f", local.userdata_bytes / 1024)
    aws_limit_kb        = "16.00"
    remaining_bytes     = local.userdata_limit - local.userdata_bytes
    utilization_pct     = format("%.1f%%", (local.userdata_bytes / local.userdata_limit) * 100)
    status = (
      local.userdata_bytes > local.userdata_limit ? "❌ EXCEEDS LIMIT" :
      local.userdata_bytes > 14336 ? "⚠️  APPROACHING LIMIT" :
      "✓ OK"
    )
    recommendation = (
      local.userdata_bytes > local.userdata_limit && !var.compress_userdata ?
      "CRITICAL: set var.compress_userdata = true, or reduce userdata size" :
      local.userdata_bytes > local.userdata_limit ?
      "CRITICAL: over the limit even compressed - reduce extra_files or packages" :
      local.userdata_bytes > 14336 && !var.compress_userdata ?
      "Consider setting var.compress_userdata = true to compress userdata" :
      local.userdata_bytes > 14336 ?
      "Approaching limit even compressed - reduce extra_files or packages" :
      "Size is within safe limits"
    )
  }
}
