# SES Bounce Rate Alarm
# AWS recommends keeping bounce rate below 5%
resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  count = var.enable_ses_alarms ? 1 : 0

  alarm_name          = "${var.service_name}-ses-bounce-rate"
  alarm_description   = "SES bounce rate for ${var.service_name} exceeds ${var.ses_bounce_rate_threshold * 100}% (AWS recommends <5%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 3600 # 1 hour
  statistic           = "Average"
  threshold           = var.ses_bounce_rate_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = local.all_alarm_topic_arns

  tags = merge(
    {
      Name = "${var.service_name}-ses-bounce-rate"
    },
    local.tags
  )
}

# SES Complaint Rate Alarm
# AWS recommends keeping complaint rate below 0.1%
resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate" {
  count = var.enable_ses_alarms ? 1 : 0

  alarm_name          = "${var.service_name}-ses-complaint-rate"
  alarm_description   = "SES complaint rate for ${var.service_name} exceeds ${var.ses_complaint_rate_threshold * 100}% (AWS recommends <0.1%)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 3600 # 1 hour
  statistic           = "Average"
  threshold           = var.ses_complaint_rate_threshold
  treat_missing_data  = "notBreaching"

  alarm_actions = local.all_alarm_topic_arns

  tags = merge(
    {
      Name = "${var.service_name}-ses-complaint-rate"
    },
    local.tags
  )
}

# RDS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.service_name}-rds-cpu-utilization"
  alarm_description   = "RDS CPU utilization for ${var.service_name} exceeds ${var.rds_cpu_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }

  alarm_actions = local.all_alarm_topic_arns

  tags = merge(
    {
      Name = "${var.service_name}-rds-cpu"
    },
    local.tags
  )
}

# RDS Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.service_name}-rds-free-storage"
  alarm_description   = "RDS free storage for ${var.service_name} is below ${var.rds_storage_threshold_gb}GB"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_storage_threshold_gb * 1024 * 1024 * 1024 # Convert GB to bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }

  alarm_actions = local.all_alarm_topic_arns

  tags = merge(
    {
      Name = "${var.service_name}-rds-storage"
    },
    local.tags
  )
}

# RDS Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  count = var.enable_rds_alarms ? 1 : 0

  alarm_name          = "${var.service_name}-rds-connections"
  alarm_description   = "RDS database connections for ${var.service_name} exceeds ${var.rds_connections_threshold}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_connections_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.db.identifier
  }

  alarm_actions = local.all_alarm_topic_arns

  tags = merge(
    {
      Name = "${var.service_name}-rds-connections"
    },
    local.tags
  )
}
