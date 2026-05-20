output "regional_health_check_id" {
  description = "Route 53 calculated health check ID. Pass this as `health_check_id` on a Route 53 record set for latency-based or failover routing."
  value       = aws_route53_health_check.regional.id
}

output "regional_health_check_arn" {
  description = "Route 53 calculated health check ARN."
  value       = aws_route53_health_check.regional.arn
}

output "regional_alarm_arn" {
  description = "Composite alarm ARN. Useful for cross-referencing in dashboards or runbooks."
  value       = aws_cloudwatch_composite_alarm.regional.arn
}

output "regional_alarm_name" {
  description = "Composite alarm name."
  value       = aws_cloudwatch_composite_alarm.regional.alarm_name
}

output "child_health_check_ids" {
  description = "Per-metric Route 53 health check IDs, keyed by metric_alarms map key."
  value       = { for key, hc in aws_route53_health_check.child : key => hc.id }
}

output "child_alarm_names" {
  description = "Per-metric CloudWatch alarm names, keyed by metric_alarms map key."
  value       = { for key, alarm in aws_cloudwatch_metric_alarm.child : key => alarm.alarm_name }
}
