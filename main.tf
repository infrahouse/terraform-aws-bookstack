locals {
  efs_mount_path = "/mnt/efs"
}
module "bookstack-userdata" {
  source  = "registry.infrahouse.com/infrahouse/cloud-init/aws"
  version = "2.3.1"

  environment              = var.environment
  role                     = "bookstack"
  puppet_hiera_config_path = var.puppet_hiera_config_path
  puppet_module_path       = var.puppet_module_path
  puppet_root_directory    = var.puppet_root_directory
  puppet_debug_logging     = var.puppet_debug_logging
  ubuntu_codename          = var.ubuntu_codename
  gzip_userdata            = var.compress_userdata

  packages = concat(
    var.packages,
    [
      "mysql-client",
      "nfs-common"
    ]
  )
  extra_files = concat(
    var.extra_files,
    [
      {
        content     = templatefile("${path.module}/files/test-db-connectivity.sh", {})
        path        = "/usr/local/bin/test-db-connectivity.sh"
        permissions = "0755"
      }
    ]
  )
  extra_repos = var.extra_repos

  # Pre-seed /var/tmp/bookstack.tar.gz with a tarball that already contains the
  # composer vendor/ dir, BEFORE Puppet runs. This satisfies the `creates` guards
  # on the Puppet profile's download_package and run_composer execs, so neither
  # runs at boot — composer never executes and never contacts the (flaky) Codeberg
  # archive endpoint. Set bookstack_prebuilt_package_url = null to fall back to the
  # stock flow (Puppet downloads source + runs composer install).
  #
  # The artifact is verified against bookstack_prebuilt_package_sha256: a mismatch
  # (tampered/replaced object, or corrupt download) deletes the file and fails the
  # bootstrap, so untrusted code is never unpacked into the application.
  pre_runcmd = var.bookstack_prebuilt_package_url != null ? concat(
    ["curl -fsSL -o /var/tmp/bookstack.tar.gz ${var.bookstack_prebuilt_package_url}"],
    var.bookstack_prebuilt_package_sha256 != null ? [
      "echo '${var.bookstack_prebuilt_package_sha256}  /var/tmp/bookstack.tar.gz' > /var/tmp/bookstack.tar.gz.sha256sum",
      "sha256sum -c /var/tmp/bookstack.tar.gz.sha256sum || { rm -f /var/tmp/bookstack.tar.gz; exit 1; }"
    ] : []
  ) : []

  custom_facts = merge(
    {
      "bookstack" : {
        "uploads_dir" : "${local.efs_mount_path}/uploads"
        "app_key_secret" : module.bookstack_app_key.secret_name
        "app_url" : "https://${var.service_name}.${data.aws_route53_zone.current.name}"
        "db_host" : module.rds.db_instance_address
        "db_port" : module.rds.db_instance_port
        "db_database" : module.rds.db_instance_name
        "db_username" : module.rds.db_instance_username
        "db_password_secret" : data.aws_secretsmanager_secret.master.name
        "mail_host" : local.smtp_endpoints[data.aws_region.current.region]
        "mail_port" : 587
        "mail_encryption" : "tls"
        "mail_verify_ssl" : false
        "mail_username" : aws_iam_access_key.emailer.id
        "mail_password_secret" : module.ses_smtp_password.secret_name
        "mail_from" : "BookStack@${data.aws_route53_zone.current.name}"
        "mail_from_name" : "BookStack"
        "google_oauth_client_secret" : data.aws_secretsmanager_secret.google_client.name
      }
      "efs" : {
        "file_system_id" : aws_efs_file_system.bookstack-uploads.id
        "dns_name" : aws_efs_file_system.bookstack-uploads.dns_name
      }
    },
    var.smtp_credentials_secret != null ? {
      postfix : {
        smtp_credentials : var.smtp_credentials_secret
      }
    } : {}
  )
}

module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/website-pod/aws"
  version = "6.0.1"
  providers = {
    aws     = aws
    aws.dns = aws.dns
  }
  service_name                          = var.service_name
  environment                           = var.environment
  ami                                   = var.asg_ami != null ? var.asg_ami : data.aws_ami.ubuntu_pro.image_id
  subnets                               = var.lb_subnet_ids
  backend_subnets                       = var.backend_subnet_ids
  zone_id                               = var.zone_id
  replication_region                    = var.access_log_replication_region
  key_pair_name                         = var.key_pair_name == null ? aws_key_pair.deployer.key_name : var.key_pair_name
  ssh_cidr_block                        = var.ssh_cidr_block
  dns_a_records                         = local.dns_a_records
  alb_name_prefix                       = substr(var.service_name, 0, 6) ## "name_prefix" cannot be longer than 6 characters: "elastic"
  userdata                              = module.bookstack-userdata.userdata
  instance_profile_permissions          = data.aws_iam_policy_document.instance_permissions.json
  alb_access_log_force_destroy          = var.access_log_force_destroy
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
  sns_topic_alarm_arn                   = var.sns_topic_alarm_arn
  alarm_emails                          = var.alarm_emails
  asg_min_elb_capacity                  = 1
  instance_role_name                    = local.ec2_role_name
  tags = merge(
    {
      Name : var.service_name
      service : var.service_name
    },
    local.tags
  )
}

resource "random_string" "role-suffix" {
  length  = 6
  special = false
}
