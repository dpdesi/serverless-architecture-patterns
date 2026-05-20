output "alarm_topic_arn" {
  description = "SNS topic ARN for alarms."
  value       = aws_sns_topic.alarms.arn
}

output "adot_environment_variables" {
  description = "Environment variables to merge into Lambda functions that use the ADOT layer."
  value       = local.adot_environment_variables
}

output "dashboard_name" {
  description = "CloudWatch dashboard name when enabled."
  value       = try(aws_cloudwatch_dashboard.this[0].dashboard_name, null)
}

output "alarm_names" {
  description = "CloudWatch alarm names grouped by signal."
  value = {
    errors    = { for key, alarm in aws_cloudwatch_metric_alarm.lambda_errors : key => alarm.alarm_name }
    throttles = { for key, alarm in aws_cloudwatch_metric_alarm.lambda_throttles : key => alarm.alarm_name }
    duration  = { for key, alarm in aws_cloudwatch_metric_alarm.lambda_duration : key => alarm.alarm_name }
    dlq       = { for key, alarm in aws_cloudwatch_metric_alarm.dlq_depth : key => alarm.alarm_name }
  }
}
