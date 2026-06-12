output "ingress_function_name" {
  description = "Ingress Lambda function name."
  value       = module.ingress.function_name
}

output "egress_function_name" {
  description = "Egress Lambda function name. Null on an ingress-only gateway."
  value       = try(module.egress[0].function_name, null)
}

output "webhook_api_endpoint" {
  description = "Webhook API endpoint when enabled."
  value       = try(module.webhook_api[0].api_endpoint, null)
}

output "egress_queue_arn" {
  description = "Egress queue ARN. Null on an ingress-only gateway."
  value       = try(aws_sqs_queue.egress[0].arn, null)
}

output "egress_dlq_arn" {
  description = "Egress queue dead-letter queue ARN. Null on an ingress-only gateway."
  value       = try(aws_sqs_queue.egress_dlq[0].arn, null)
}

output "egress_dlq_name" {
  description = "Egress queue dead-letter queue name. Useful for observability_baseline depth alarms. Null on an ingress-only gateway."
  value       = try(aws_sqs_queue.egress_dlq[0].name, null)
}

output "egress_rule_name" {
  description = "EventBridge egress rule name. Null on an ingress-only gateway."
  value       = try(aws_cloudwatch_event_rule.egress[0].name, null)
}

output "egress_rule_dlq_arn" {
  description = "DLQ ARN for failed EventBridge deliveries to the egress queue. Null on an ingress-only gateway."
  value       = try(aws_sqs_queue.egress_rule_dlq[0].arn, null)
}

output "egress_rule_dlq_name" {
  description = "DLQ name for failed EventBridge deliveries. Useful for observability_baseline depth alarms. Null on an ingress-only gateway."
  value       = try(aws_sqs_queue.egress_rule_dlq[0].name, null)
}

output "timeout_seconds" {
  description = "Effective Lambda timeout. Feed this to observability_baseline so the duration alarm threshold tracks the real timeout."
  value       = var.timeout
}
