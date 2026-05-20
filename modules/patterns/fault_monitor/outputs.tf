output "bucket_name" {
  description = "Fault archive bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Fault archive bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "delivery_stream_arn" {
  description = "Firehose delivery stream ARN. Useful for callers that wire additional EventBridge rules to the same archive."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "rule_name" {
  description = "EventBridge rule name matching fault events."
  value       = aws_cloudwatch_event_rule.faults.name
}

output "rule_dlq_arn" {
  description = "DLQ ARN for failed deliveries from the fault rule."
  value       = aws_sqs_queue.rule_dlq.arn
}

output "fault_topic_arn" {
  description = "SNS topic ARN published to whenever a fault event matches. Pair with the observability_baseline alarm topic for unified routing."
  value       = aws_sns_topic.faults.arn
}

output "fault_arrival_alarm_arn" {
  description = "CloudWatch alarm ARN that fires on any matched fault event."
  value       = aws_cloudwatch_metric_alarm.fault_arrival.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for the bucket, queue, and topic."
  value       = local.effective_kms_key_arn
}
