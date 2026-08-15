# Basic Example
# The minimum configuration required to deploy BookStack in a new VPC.

terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  environment = "development"
  domain_name = "example.com"
}

# Public subnets host the load balancer, private subnets host the BookStack
# instances, the RDS instance and the EFS mount targets.
module "network" {
  source  = "registry.infrahouse.com/infrahouse/service-network/aws"
  version = "5.0.2"

  environment           = local.environment
  service_name          = "bookstack"
  vpc_cidr_block        = "10.1.0.0/16"
  management_cidr_block = "10.1.0.0/16"
  replication_region    = "us-east-1"
  subnets = [
    {
      cidr                    = "10.1.0.0/24"
      availability_zone       = "us-west-2a"
      map_public_ip_on_launch = true
      create_nat              = true
    },
    {
      cidr                    = "10.1.1.0/24"
      availability_zone       = "us-west-2b"
      map_public_ip_on_launch = true
    },
    {
      cidr              = "10.1.100.0/24"
      availability_zone = "us-west-2a"
      forward_to        = "10.1.0.0/24" # subnet with the NAT gateway
    },
    {
      cidr              = "10.1.101.0/24"
      availability_zone = "us-west-2b"
      forward_to        = "10.1.0.0/24"
    },
  ]
}

# The hosted zone where the bookstack.example.com record is created.
data "aws_route53_zone" "current" {
  name = local.domain_name
}

# BookStack authenticates users with a Google OAuth client. Download the client
# JSON from the Google Cloud Console and store it in Secrets Manager. The EC2
# instances read the secret at boot, so the instance role must be a reader.
module "google_client" {
  source  = "registry.infrahouse.com/infrahouse/secret/aws"
  version = "1.3.0"

  environment        = local.environment
  service_name       = "bookstack"
  secret_name_prefix = "bookstack_google_client"
  secret_description = "Google OAuth client id and secret for BookStack"
  secret_value       = var.google_oauth_client_json
  readers = [
    module.bookstack.bookstack_instance_role_arn
  ]
}

module "bookstack" {
  source  = "registry.infrahouse.com/infrahouse/bookstack/aws"
  version = "4.2.1"
  providers = {
    aws = aws
    # DNS records may live in another AWS account. Point aws.dns to a provider
    # configured for that account if they do.
    aws.dns = aws
  }

  environment                   = local.environment
  lb_subnet_ids                 = module.network.subnet_public_ids
  backend_subnet_ids            = module.network.subnet_private_ids
  zone_id                       = data.aws_route53_zone.current.zone_id
  google_oauth_client_secret    = module.google_client.secret_name
  access_log_replication_region = "us-east-1"

  # Each address receives an SNS subscription confirmation email that must be
  # confirmed before alarm notifications are delivered.
  alarm_emails = ["ops-team@example.com"]
}

output "bookstack_urls" {
  description = "URLs where BookStack is available"
  value       = module.bookstack.bookstack_urls
}

output "database_address" {
  description = "Address of the RDS instance"
  value       = module.bookstack.database_address
}

output "userdata_size_info" {
  description = "How much of the 16KB EC2 userdata limit is used"
  value       = module.bookstack.userdata_size_info
}
