data "aws_ses_domain_identity" "zone" {
  domain = data.aws_route53_zone.current.name
}

resource "aws_iam_user" "bookstack-emailer" {
  name = "bookstack-emailer"
  tags = local.tags
}

resource "aws_iam_access_key" "bookstack-emailer" {
  user = aws_iam_user.bookstack-emailer.name
}

data "aws_iam_policy_document" "bookstack-emailer-permissions" {
  statement {
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "bookstack-emailer" {
  name   = "bookstack-emailer"
  policy = data.aws_iam_policy_document.bookstack-emailer-permissions.json
}

resource "aws_iam_user_policy_attachment" "bookstack-emailer" {
  user       = aws_iam_user.bookstack-emailer.name
  policy_arn = aws_iam_policy.bookstack-emailer.arn
}
