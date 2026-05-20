output "api_endpoint" {
  description = "BFF API endpoint."
  value       = module.api.api_endpoint
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
