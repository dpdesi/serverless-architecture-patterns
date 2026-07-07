output "bucket_name" {
  description = "Artefact bucket name. This is the value for artefact_defaults.bucket in a subsystem manifest."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Artefact bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "publisher_role_arn" {
  description = "IAM role a GitHub Actions workflow assumes (via id-token) to publish artefacts, when github_oidc is configured; else null."
  value       = local.oidc_enabled ? aws_iam_role.publisher[0].arn : null
}

output "kms_key_arn" {
  description = "KMS key ARN encrypting the bucket."
  value       = local.effective_kms_key_arn
}
