output "bookstack_urls" {
  value = module.bookstack.bookstack_urls
}

output "autoscaling_group_name" {
  value = module.bookstack.autoscaling_group_name
}

output "database_address" {
  value = module.bookstack.database_address
}

output "database_port" {
  value = module.bookstack.database_port
}

output "database_name" {
  value = module.bookstack.database_name
}

output "database_secret_name" {
  value = module.bookstack.database_secret_name
}
