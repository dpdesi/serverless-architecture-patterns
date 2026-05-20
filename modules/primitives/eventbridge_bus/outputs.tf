output "name" {
  description = "EventBridge bus name."
  value       = aws_cloudwatch_event_bus.this.name
}

output "arn" {
  description = "EventBridge bus ARN."
  value       = aws_cloudwatch_event_bus.this.arn
}

output "archive_arn" {
  description = "Archive ARN when enabled."
  value       = try(aws_cloudwatch_event_archive.this[0].arn, null)
}
