output "event_bus_name" {
  description = "Subsystem event bus name."
  value       = module.event_hub.bus_name
}

output "event_bus_arn" {
  description = "Subsystem event bus ARN."
  value       = module.event_hub.bus_arn
}

output "bff_api_endpoint" {
  description = "Customer BFF API endpoint."
  value       = module.customer_bff.api_endpoint
}

output "customer_table_name" {
  description = "Customer BFF table name."
  value       = module.customer_bff.table_name
}

output "regions" {
  description = "Primary and secondary regions configured by provider aliases."
  value = {
    primary   = data.aws_region.primary.name
    secondary = data.aws_region.secondary.name
  }
}
