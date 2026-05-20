output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "CloudFront distribution ARN."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "Default CloudFront domain name (use as the alias target in Route53)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID for CloudFront aliases. Use with `aws_route53_record` alias targets."
  value       = aws_cloudfront_distribution.this.hosted_zone_id
}

output "primary_origin_bucket_id" {
  description = "Primary origin bucket name."
  value       = aws_s3_bucket.primary.id
}

output "primary_origin_bucket_arn" {
  description = "Primary origin bucket ARN."
  value       = aws_s3_bucket.primary.arn
}

output "primary_origin_bucket_regional_domain_name" {
  description = "Primary origin bucket regional domain name. Useful when this distribution is itself the secondary for a peer in another region."
  value       = aws_s3_bucket.primary.bucket_regional_domain_name
}

output "primary_origin_access_control_id" {
  description = "Origin Access Control ID for the primary origin. Pass to a peer distribution as its `secondary_origin.origin_access_control_id`."
  value       = aws_cloudfront_origin_access_control.primary.id
}

output "response_headers_policy_id" {
  description = "Response headers policy ID for the security defaults applied to all behaviours."
  value       = aws_cloudfront_response_headers_policy.this.id
}

output "kms_key_arn" {
  description = "KMS key ARN used for the primary origin bucket."
  value       = local.effective_kms_key_arn
}
