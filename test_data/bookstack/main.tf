module "bookstack" {
  source = "../../"
  providers = {
    aws     = aws
    aws.dns = aws
  }

  backend_subnet_ids         = var.backend_subnet_ids
  internet_gateway_id        = var.internet_gateway_id
  lb_subnet_ids              = var.lb_subnet_ids
  zone_id                    = data.aws_route53_zone.test-zone.zone_id
  asg_min_size               = 1
  asg_max_size               = 1
  google_oauth_client_secret = module.google_client.secret_name
  ubuntu_codename            = var.ubuntu_codename
  ssh_cidr_block             = "0.0.0.0/0"
  access_log_force_destroy   = true
  skip_final_snapshot        = true
  deletion_protection        = false
  alarm_emails = [
    "test-alarms@infrahouse.com"
  ]
}
