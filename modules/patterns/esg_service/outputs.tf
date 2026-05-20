output "ingress_function_name" {
  description = "Ingress Lambda function name."
  value       = module.ingress.function_name
}

output "egress_function_name" {
  description = "Egress Lambda function name."
  value       = module.egress.function_name
}

output "webhook_api_endpoint" {
  description = "Webhook API endpoint when enabled."
  value       = try(module.webhook_api[0].api_endpoint, null)
}

output "egress_queue_arn" {
  description = "Egress queue ARN."
  value       = aws_sqs_queue.egress.arn
}

output "egress_dlq_arn" {
  description = "Egress queue dead-letter queue ARN."
  value       = aws_sqs_queue.egress_dlq.arn
}

output "egress_dlq_name" {
  description = "Egress queue dead-letter queue name. Useful for observability_baseline depth alarms."
  value       = aws_sqs_queue.egress_dlq.name
}

output "egress_rule_name" {
  description = "EventBridge egress rule name."
  value       = aws_cloudwatch_event_rule.egress.name
}
