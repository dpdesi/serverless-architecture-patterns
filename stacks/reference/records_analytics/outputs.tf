output "event_lake_bucket_name" {
  value = module.event_lake.bucket_name
}

output "delivery_stream_name" {
  value = module.event_lake.delivery_stream_name
}

output "alarm_topic_arn" {
  value = module.observability.alarm_topic_arn
}
