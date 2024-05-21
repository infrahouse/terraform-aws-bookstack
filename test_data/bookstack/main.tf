module "test" {
  source = "../../"
  providers = {
    aws     = aws
    aws.dns = aws
  }

  backend_subnet_ids  = var.backend_subnet_ids
  internet_gateway_id = var.internet_gateway_id
  lb_subnet_ids       = var.lb_subnet_ids
  zone_id             = data.aws_route53_zone.test-zone.zone_id
  key_pair_name       = aws_key_pair.mediapc.key_name
  asg_min_size        = 1
  asg_max_size        = 1
}
