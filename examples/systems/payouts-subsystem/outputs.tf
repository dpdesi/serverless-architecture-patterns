output "bus_name" {
  description = "Payouts event hub bus name."
  value       = module.payouts.bus_name
}

output "api_endpoints" {
  description = "BFF API endpoints keyed by BFF name."
  value       = module.payouts.api_endpoints
}

output "api_origins" {
  description = "Feed to frontend_edge in a us-east-1 edge root to publish the ops portal."
  value       = module.payouts.api_origins
}

output "hub_route_keys" {
  description = "Derived hub routes - useful to confirm what the manifest produced."
  value       = module.payouts.hub_route_keys
}

output "monitored_functions" {
  description = "Lambda functions wired into the observability baseline."
  value       = module.payouts.monitored_functions
}

output "event_lake_bucket_name" {
  description = "Regulatory audit trail bucket."
  value       = module.payouts.event_lake_bucket_name
}
