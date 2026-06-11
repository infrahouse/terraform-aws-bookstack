# SES Bounce Rate Alarm
# AWS recommends keeping bounce rate below 5%
resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
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

# The SES alarms were previously gated by var.enable_ses_alarms (count). They are
# now unconditional; these moved blocks adopt the existing instances in place.
moved {
  from = aws_cloudwatch_metric_alarm.ses_bounce_rate[0]
  to   = aws_cloudwatch_metric_alarm.ses_bounce_rate
}

moved {
  from = aws_cloudwatch_metric_alarm.ses_complaint_rate[0]
  to   = aws_cloudwatch_metric_alarm.ses_complaint_rate
}
