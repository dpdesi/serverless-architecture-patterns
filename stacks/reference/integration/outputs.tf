output "event_bus_name" {
  value = module.event_hub.bus_name
}

output "webhook_api_endpoint" {
  value = module.esg.webhook_api_endpoint
}

output "egress_queue_arn" {
  value = module.esg.egress_queue_arn
}
