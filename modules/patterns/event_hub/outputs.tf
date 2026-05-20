output "bus_name" {
  description = "Event hub bus name."
  value       = module.bus.name
}

output "bus_arn" {
  description = "Event hub bus ARN."
  value       = module.bus.arn
}

output "archive_arn" {
  description = "Event archive ARN when enabled."
  value       = module.bus.archive_arn
}

output "rule_names" {
  description = "EventBridge rule names keyed by route."
  value       = { for key, rule in aws_cloudwatch_event_rule.route : key => rule.name }
}

output "pipe_arns" {
  description = "EventBridge Pipe ARNs keyed by pipe name."
  value       = { for key, pipe in aws_pipes_pipe.this : key => pipe.arn }
}
