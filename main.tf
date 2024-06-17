locals {
  efs_mount_path = "/mnt/efs"
}
module "bookstack-userdata" {
  source                   = "infrahouse/cloud-init/aws"
  version                  = "= 1.11.1"
  environment              = var.environment
  role                     = "bookstack"
  puppet_hiera_config_path = var.puppet_hiera_config_path
  puppet_module_path       = var.puppet_module_path

  packages = concat(
    var.packages,
    [
      "nfs-common"
    ]
  )
  pre_runcmd = [
    "/opt/puppetlabs/puppet/bin/gem install json",
    "/opt/puppetlabs/puppet/bin/gem install aws-sdk-core",
    "/opt/puppetlabs/puppet/bin/gem install aws-sdk-secretsmanager"
  ]
  extra_files = var.extra_files
  extra_repos = var.extra_repos

  custom_facts = {
    "bookstack" : {
      "uploads_dir" : "${local.efs_mount_path}/uploads"
      "app_key_secret" : aws_secretsmanager_secret.bookstack_app_key.name
      "app_url" : "https://${var.service_name}.${data.aws_route53_zone.current.name}"
      "db_host" : aws_db_instance.db.address
      "db_database" : aws_db_instance.db.db_name
      "db_username" : jsondecode(aws_secretsmanager_secret_version.db_user.secret_string)["user"]
      "db_password_secret" : aws_secretsmanager_secret.db_user.name
      "mail_host" : local.smtp_endpoints[data.aws_region.current.name]
      "mail_port" : 587
      "mail_encryption" : "tls"
      "mail_verify_ssl" : false
      "mail_username" : aws_iam_access_key.bookstack-emailer.id
      "mail_password_secret" : aws_secretsmanager_secret.ses_smtp_password.name
      "mail_from" : "BookStack@${data.aws_route53_zone.current.name}"
      "mail_from_name" : "BookStack"
      "google_oauth_client_secret" : data.aws_secretsmanager_secret.google_client.name
    }
    "efs" : {
      "file_system_id" : aws_efs_file_system.bookstack-uploads.id
      "dns_name" : aws_efs_file_system.bookstack-uploads.dns_name
    }
  }
}

module "bookstack" {
  source  = "infrahouse/website-pod/aws"
  version = "3.1.0"
  providers = {
    aws     = aws
    aws.dns = aws.dns
  }
  service_name                          = var.service_name
  environment                           = var.environment
  ami                                   = var.asg_ami != null ? var.asg_ami : data.aws_ami.ubuntu.image_id
  subnets                               = var.lb_subnet_ids
  backend_subnets                       = var.backend_subnet_ids
  zone_id                               = var.zone_id
  alb_internal                          = var.alb_internal
  internet_gateway_id                   = var.internet_gateway_id
  key_pair_name                         = var.key_pair_name == null ? aws_key_pair.deployer.key_name : var.key_pair_name
  dns_a_records                         = var.dns_a_records == null ? [var.service_name] : var.dns_a_records
  alb_name_prefix                       = substr(var.service_name, 0, 6) ## "name_prefix" cannot be longer than 6 characters: "elastic"
  userdata                              = module.bookstack-userdata.userdata
  webserver_permissions                 = data.aws_iam_policy_document.instance_permissions.json
  alb_access_log_enabled                = true
  stickiness_enabled                    = true
  asg_min_size                          = var.asg_min_size == null ? length(var.backend_subnet_ids) : var.asg_min_size
  asg_max_size                          = var.asg_max_size == null ? length(var.backend_subnet_ids) + 1 : var.asg_max_size
  instance_type                         = var.instance_type
  target_group_port                     = 80
  alb_healthcheck_path                  = "/login"
  alb_healthcheck_port                  = 80
  alb_healthcheck_response_code_matcher = "200"
  alb_healthcheck_interval              = 30
  health_check_grace_period             = var.asg_health_check_grace_period
  wait_for_capacity_timeout             = "${var.asg_health_check_grace_period * 1.5}m"

  asg_min_elb_capacity = 1
  instance_role_name = var.instance_role_name
  tags = {
    Name : var.service_name
    service : var.service_name
  }
}

resource "random_string" "profile-suffix" {
  length  = 6
  special = false
}
