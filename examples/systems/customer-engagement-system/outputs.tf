output "system_name" {
  description = "Example system name."
  value       = var.system_name
}

output "subsystem_name" {
  description = "Example subsystem name."
  value       = var.subsystem_name
}

output "bff_api_endpoint" {
  description = "Public BFF HTTP API endpoint."
  value       = module.customer_bff.api_endpoint
}

output "external_crm_webhook_endpoint" {
  description = "Webhook endpoint exposed by the External Service Gateway."
  value       = module.external_crm_esg.webhook_api_endpoint
}

output "event_bus_name" {
  description = "Subsystem event hub bus name."
  value       = module.event_hub.bus_name
}

output "event_lake_bucket_name" {
  description = "Event lake S3 bucket."
  value       = module.event_lake.bucket_name
}

output "observability_dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = module.observability.dashboard_name
}

output "control_event_store_table_name" {
  description = "Control Service private event store table."
  value       = module.customer_control.table_name
}

output "customer_table_name" {
  description = "BFF-owned customer table."
  value       = module.customer_bff.table_name
}

