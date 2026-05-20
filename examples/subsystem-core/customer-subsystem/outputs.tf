output "event_bus_name" {
  value = module.event_hub.bus_name
}

output "bff_api_endpoint" {
  value = module.customer_bff.api_endpoint
}

output "customer_table_name" {
  value = module.customer_bff.table_name
}
