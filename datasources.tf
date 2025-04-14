data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu_pro" {
  most_recent = true

  filter {
    name   = "name"
    values = [local.ami_name_pattern_pro]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "state"
    values = [
      "available"
    ]
  }

  owners = ["099720109477"] # Canonical
}



data "aws_subnet" "selected" {
  id = var.backend_subnet_ids[0]
}

data "aws_route53_zone" "current" {
  provider = aws.dns
  zone_id  = var.zone_id
}

data "aws_iam_policy_document" "instance_permissions" {
  source_policy_documents = var.extra_instance_profile_permissions != null ? [var.extra_instance_profile_permissions] : []
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      module.bookstack_app_key.secret_arn,
      module.db_user.secret_arn,
      module.ses_smtp_password.secret_arn,
      data.aws_secretsmanager_secret.google_client.arn
    ]
  }
}

data "aws_vpc" "selected" {
  id = data.aws_subnet.selected.vpc_id
}
