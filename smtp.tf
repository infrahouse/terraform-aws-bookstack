data "aws_ses_domain_identity" "zone" {
  domain = data.aws_route53_zone.current.name
}

# IAM user for sending emails via SES
resource "aws_iam_user" "emailer" {
  name = "${var.service_name}-emailer"
  tags = local.tags
}

# Time-based rotation trigger
resource "time_rotating" "key_rotation" {
  rotation_days = var.smtp_key_rotation_days
}

# Static time resource to properly trigger replacement
# This is a workaround for https://github.com/hashicorp/terraform-provider-time/issues/118
resource "time_static" "key_rotation" {
  rfc3339 = time_rotating.key_rotation.rfc3339
}

# Access key with automatic rotation
resource "aws_iam_access_key" "emailer" {
  user = aws_iam_user.emailer.name

  lifecycle {
    replace_triggered_by = [
      time_static.key_rotation
    ]
    create_before_destroy = true
  }
}

# SES permissions with domain restriction
data "aws_iam_policy_document" "emailer_permissions" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["*@${data.aws_route53_zone.current.name}"]
    }
  }
}

resource "aws_iam_policy" "emailer" {
  name   = "${var.service_name}-emailer"
  policy = data.aws_iam_policy_document.emailer_permissions.json

  tags = local.tags
}

resource "aws_iam_user_policy_attachment" "emailer" {
  user       = aws_iam_user.emailer.name
  policy_arn = aws_iam_policy.emailer.arn
}