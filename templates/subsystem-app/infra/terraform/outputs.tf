output "bus_name" {
  description = "Subsystem event hub bus name."
  value       = module.subsystem.bus_name
}

output "api_endpoints" {
  description = "BFF API endpoints keyed by BFF name."
  value       = module.subsystem.api_endpoints
}

output "api_origins" {
  description = "BFF origins (consumed by the edge slot when enabled)."
  value       = module.subsystem.api_origins
}

output "hub_route_keys" {
  description = "Derived hub routes - confirms what the manifest produced."
  value       = module.subsystem.hub_route_keys
}

output "monitored_functions" {
  description = "Lambda functions wired into the observability baseline."
  value       = module.subsystem.monitored_functions
}

output "edge_domain" {
  description = "CloudFront domain when the edge is enabled, otherwise null."
  value       = try(module.edge[0].distribution_domain_name, null)
}
