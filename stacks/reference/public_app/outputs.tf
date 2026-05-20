output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.frontend_edge.distribution_id
}

output "distribution_domain_name" {
  description = "Default CloudFront domain name."
  value       = module.frontend_edge.distribution_domain_name
}

output "manifest_bucket_name" {
  description = "Bucket where micro-app CI/CD pipelines upload their mfe.json fragments."
  value       = module.micro_frontend.bucket_name
}

output "bff_api_endpoint" {
  description = "BFF HTTP API endpoint."
  value       = module.bff.api_endpoint
}

output "regional_health_check_id" {
  description = "Route 53 calculated health check ID for the primary region."
  value       = module.regional_health_check.regional_health_check_id
}

output "fault_bucket_name" {
  description = "S3 bucket archiving fault events."
  value       = module.fault_monitor.bucket_name
}

output "alarm_topic_arn" {
  description = "Observability baseline SNS topic for alarms."
  value       = module.observability.alarm_topic_arn
}
