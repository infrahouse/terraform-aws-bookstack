locals {
  environment = "development"
}
resource "aws_key_pair" "mediapc" {
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDpgAP1z1Lxg9Uv4tam6WdJBcAftZR4ik7RsSr6aNXqfnTj4civrhd/q8qMqF6wL//3OujVDZfhJcffTzPS2XYhUxh/rRVOB3xcqwETppdykD0XZpkHkc8XtmHpiqk6E9iBI4mDwYcDqEg3/vrDAGYYsnFwWmdDinxzMH1Gei+NPTmTqU+wJ1JZvkw3WBEMZKlUVJC/+nuv+jbMmCtm7sIM4rlp2wyzLWYoidRNMK97sG8+v+mDQol/qXK3Fuetj+1f+vSx2obSzpTxL4RYg1kS6W1fBlSvstDV5bQG4HvywzN5Y8eCpwzHLZ1tYtTycZEApFdy+MSfws5vPOpggQlWfZ4vA8ujfWAF75J+WABV4DlSJ3Ng6rLMW78hVatANUnb9s4clOS8H6yAjv+bU3OElKBkQ10wNneoFIMOA3grjPvPp5r8dI0WDXPIznJThDJO5yMCy3OfCXlu38VDQa1sjVj1zAPG+Vn2DsdVrl50hWSYSB17Zww0MYEr8N5rfFE= aleks@MediaPC"
}
module "jumphost" {
  source                   = "registry.infrahouse.com/infrahouse/jumphost/aws"
  version                  = "~> 2.3"
  environment              = local.environment
  keypair_name             = aws_key_pair.mediapc.key_name
  route53_zone_id          = data.aws_route53_zone.test-zone.zone_id
  subnet_ids               = var.backend_subnet_ids
  nlb_subnet_ids           = var.lb_subnet_ids
  asg_min_size             = 1
  asg_max_size             = 1
  puppet_hiera_config_path = "/opt/infrahouse-puppet-data/environments/${local.environment}/hiera.yaml"
  packages = [
    "infrahouse-puppet-data"
  ]
  ssh_host_keys = [
    {
      type : "rsa"
      private : file("${path.module}/ssh_keys/ssh_host_rsa_key")
      public : file("${path.module}/ssh_keys/ssh_host_rsa_key.pub")
    },
    {
      type : "ecdsa"
      private : file("${path.module}/ssh_keys/ssh_host_ecdsa_key")
      public : file("${path.module}/ssh_keys/ssh_host_ecdsa_key.pub")
    },
    {
      type : "ed25519"
      private : file("${path.module}/ssh_keys/ssh_host_ed25519_key")
      public : file("${path.module}/ssh_keys/ssh_host_ed25519_key.pub")
    }
  ]
}
