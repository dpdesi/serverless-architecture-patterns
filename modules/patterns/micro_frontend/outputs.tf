output "bucket_name" {
  description = "Manifest bucket name. Micro-app CI/CD pipelines upload their `mfe.json` to `s3://<bucket>/<manifests_prefix><orgName>-<projectName>.json`."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Manifest bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "manifests_prefix" {
  description = "Bucket key prefix watched by the deployer Lambda."
  value       = var.manifests_prefix
}

output "master_prefix" {
  description = "Bucket key prefix where the consolidated master manifests are written. Use this as the CloudFront origin path to serve `importmap.json`, `apps.json`, and `mount-points.json` to the main app."
  value       = var.master_prefix
}

output "deployer_function_name" {
  description = "Deployer Lambda function name."
  value       = module.deployer.function_name
}

output "deployer_function_arn" {
  description = "Deployer Lambda function ARN."
  value       = module.deployer.function_arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for the bucket and Lambda environment encryption."
  value       = local.effective_kms_key_arn
}
