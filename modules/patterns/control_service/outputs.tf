output "mode" {
  description = "Control Service mode."
  value       = var.mode
}

output "table_name" {
  description = "Micro event store table name in event_reactor mode."
  value       = try(module.table[0].name, null)
}

output "listener_queue_arn" {
  description = "Listener queue ARN in event_reactor mode."
  value       = try(aws_sqs_queue.listener[0].arn, null)
}

output "listener_dlq_arn" {
  description = "Listener queue dead-letter queue ARN in event_reactor mode."
  value       = try(aws_sqs_queue.listener_dlq[0].arn, null)
}

output "listener_dlq_name" {
  description = "Listener queue dead-letter queue name in event_reactor mode."
  value       = try(aws_sqs_queue.listener_dlq[0].name, null)
}

output "trigger_dlq_arn" {
  description = "Stream trigger on-failure destination ARN in event_reactor mode."
  value       = try(aws_sqs_queue.trigger_dlq[0].arn, null)
}

output "trigger_dlq_name" {
  description = "Stream trigger on-failure destination name in event_reactor mode."
  value       = try(aws_sqs_queue.trigger_dlq[0].name, null)
}

output "lambda_function_names" {
  description = "Lambda function names in event_reactor mode."
  value = {
    listener = try(module.listener[0].function_name, null)
    trigger  = try(module.trigger[0].function_name, null)
  }
}

output "listener_rule_dlq_arn" {
  description = "DLQ ARN for failed EventBridge deliveries to the listener queue in event_reactor mode."
  value       = try(aws_sqs_queue.listener_rule_dlq[0].arn, null)
}

output "listener_rule_dlq_name" {
  description = "DLQ name for failed EventBridge deliveries to the listener queue in event_reactor mode."
  value       = try(aws_sqs_queue.listener_rule_dlq[0].name, null)
}

output "state_machine_arn" {
  description = "State machine ARN in step_functions mode."
  value       = try(aws_sfn_state_machine.this[0].arn, null)
}

output "workflow_rule_dlq_arn" {
  description = "DLQ ARN for failed EventBridge starts of the state machine in step_functions mode."
  value       = try(aws_sqs_queue.workflow_rule_dlq[0].arn, null)
}

output "workflow_rule_dlq_name" {
  description = "DLQ name for failed EventBridge starts of the state machine in step_functions mode."
  value       = try(aws_sqs_queue.workflow_rule_dlq[0].name, null)
}

output "timeout_seconds" {
  description = "Effective Lambda timeout. Feed this to observability_baseline so the duration alarm threshold tracks the real timeout."
  value       = var.timeout
}
