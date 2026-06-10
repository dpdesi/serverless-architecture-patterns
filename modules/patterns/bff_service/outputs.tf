output "api_endpoint" {
  description = "BFF API endpoint (full URL including scheme)."
  value       = module.api.api_endpoint
}

output "api_domain_name" {
  description = "Host-only portion of the BFF API endpoint. Pass this as `frontend_edge.api_origins[<key>].domain_name` to mount the BFF behind a shared CloudFront distribution."
  value       = module.api.api_domain_name
}

output "api_id" {
  description = "BFF API ID."
  value       = module.api.api_id
}

output "table_name" {
  description = "BFF table name."
  value       = module.table.name
}

output "table_arn" {
  description = "BFF table ARN."
  value       = module.table.arn
}

output "listener_queue_arn" {
  description = "Listener queue ARN."
  value       = aws_sqs_queue.listener.arn
}

output "listener_queue_url" {
  description = "Listener queue URL. Needed by compositions that attach an SQS queue policy for EventBridge delivery."
  value       = aws_sqs_queue.listener.url
}

output "listener_queue_name" {
  description = "Listener queue name."
  value       = aws_sqs_queue.listener.name
}

output "listener_dlq_arn" {
  description = "Listener queue dead-letter queue ARN."
  value       = aws_sqs_queue.listener_dlq.arn
}

output "listener_dlq_name" {
  description = "Listener queue dead-letter queue name. Useful for observability_baseline depth alarms."
  value       = aws_sqs_queue.listener_dlq.name
}

output "trigger_dlq_arn" {
  description = "Stream trigger on-failure destination ARN."
  value       = aws_sqs_queue.trigger_dlq.arn
}

output "trigger_dlq_name" {
  description = "Stream trigger on-failure destination name. Useful for observability_baseline depth alarms."
  value       = aws_sqs_queue.trigger_dlq.name
}

output "lambda_function_names" {
  description = "Lambda function names by component."
  value = {
    rest     = module.rest.function_name
    listener = module.listener.function_name
    trigger  = module.trigger.function_name
  }
}

output "timeout_seconds" {
  description = "Effective Lambda timeout. Feed this to observability_baseline so the duration alarm threshold tracks the real timeout."
  value       = var.timeout
}
