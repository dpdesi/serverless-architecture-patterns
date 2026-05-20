output "bucket_name" {
  description = "Event lake bucket name."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "Event lake bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "delivery_stream_name" {
  description = "Firehose delivery stream name."
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "delivery_stream_arn" {
  description = "Firehose delivery stream ARN."
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used by the event lake."
  value       = local.effective_kms_key_arn
}
