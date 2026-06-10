output "subsystem" {
  description = "Subsystem name (the resource-name prefix)."
  value       = local.name
}

output "bus_name" {
  description = "Event hub bus name."
  value       = module.hub.bus_name
}

output "bus_arn" {
  description = "Event hub bus ARN."
  value       = module.hub.bus_arn
}

output "kms_key_arn" {
  description = "The subsystem's customer-managed KMS key."
  value       = aws_kms_key.this.arn
}

output "hub_route_keys" {
  description = "Hub route keys derived from the manifest (one inbound route per subscribing BFF, plus the event-lake archive route)."
  value       = sort(keys(local.hub_routes))
}

output "hub_rule_names" {
  description = "EventBridge rule names keyed by route. The composer's queue policies predict these names - this output keeps the contract testable."
  value       = module.hub.rule_names
}

output "api_endpoints" {
  description = "BFF API endpoints keyed by BFF name."
  value       = { for k, b in local.bffs : k => module.bff[k].api_endpoint }
}

output "api_origins" {
  description = "Ready-made frontend_edge.api_origins map for BFFs that declare a path. Feed this to modules/patterns/frontend_edge in an edge root (us-east-1)."
  value = { for k, b in local.bffs : k => {
    domain_name  = module.bff[k].api_domain_name
    path_pattern = b.path
  } if can(b.path) }
}

output "table_names" {
  description = "BFF table names keyed by BFF name."
  value       = { for k, b in local.bffs : k => module.bff[k].table_name }
}

output "state_machine_arns" {
  description = "Step Functions state machine ARNs keyed by control name (step_functions mode only)."
  value       = { for k, c in local.saga_controls : k => module.control[k].state_machine_arn }
}

output "monitored_functions" {
  description = "Keys of the Lambda functions wired into the observability baseline."
  value       = sort(keys(local.observed_functions))
}

output "alarm_topic_arn" {
  description = "Observability alarm topic ARN, null when observability is disabled."
  value       = try(module.observability[0].alarm_topic_arn, null)
}

output "event_lake_bucket_name" {
  description = "Event lake bucket name, null when the lake is disabled."
  value       = try(module.event_lake[0].bucket_name, null)
}

output "fault_topic_arn" {
  description = "Fault monitor SNS topic ARN, null when the fault monitor is disabled."
  value       = try(module.fault_monitor[0].fault_topic_arn, null)
}
