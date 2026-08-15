# SNS topic for BookStack alarms.
# Left unencrypted (same rationale as the CKV_AWS_26 skip in .checkov.yml): the
# topic carries only CloudWatch/SES alarm notifications, and the AWS-managed
# aws/sns key does not grant cloudwatch.amazonaws.com permission to publish.
#trivy:ignore:AVD-AWS-0095
resource "aws_sns_topic" "alarms" {
  name = var.sns_topic_name != null ? var.sns_topic_name : "${var.service_name}-alarms"

  tags = merge(
    {
      Name = var.sns_topic_name != null ? var.sns_topic_name : "${var.service_name}-alarms"
    },
    local.tags
  )
}

# Email subscriptions for alarm notifications
resource "aws_sns_topic_subscription" "alarm_emails" {
  for_each = toset(var.alarm_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# Combine module-created topic with external topics
locals {
  all_alarm_topic_arns = concat(
    [aws_sns_topic.alarms.arn],
    var.alarm_topic_arns,
    var.sns_topic_alarm_arn != null ? [var.sns_topic_alarm_arn] : [] # Backward compatibility
  )
}
