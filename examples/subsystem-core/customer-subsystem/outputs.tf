output "event_bus_name" {
  value = module.event_hub.bus_name
}

output "listener_queue_arn" {
  value = module.customer_control.listener_queue_arn
}

output "customer_table_name" {
  value = module.customer_control.table_name
}
