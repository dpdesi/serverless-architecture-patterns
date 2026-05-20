variable "name" {
  description = "Micro-frontend deployment name. Used to derive the bucket, Lambda, and event names."
  type        = string
}

variable "deployer_artefact" {
  description = "S3 artefact reference for the manifest deployer Lambda. The function reads micro-app `mfe.json` fragments under `manifests_prefix/` and writes consolidated `importmap.json`, `apps.json`, and `mount-points.json` under `master_prefix/`."
  type = object({
    s3_bucket = string
    s3_key    = string
  })
}

variable "frontend_edge_distribution_id" {
  description = "CloudFront distribution ID to invalidate after the master manifest is rebuilt. When set, the deployer Lambda receives `DISTRIBUTION_ID` and is granted `cloudfront:CreateInvalidation`."
  type        = string
  default     = null
}

variable "frontend_edge_distribution_arn" {
  description = "CloudFront distribution ARN. Required when `frontend_edge_distribution_id` is set so the IAM policy can scope CreateInvalidation."
  type        = string
  default     = null
}

variable "manifests_prefix" {
  description = "Bucket key prefix where micro-apps upload their `mfe.json` fragments. The Lambda watches this prefix."
  type        = string
  default     = "manifests/"
}

variable "master_prefix" {
  description = "Bucket key prefix where the consolidated master manifests are written."
  type        = string
  default     = "main/"
}

variable "runtime" {
  description = "Lambda runtime for the deployer."
  type        = string
  default     = "nodejs20.x"
}

variable "handler" {
  description = "Lambda handler."
  type        = string
  default     = "index.handler"
}

variable "memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Lambda timeout in seconds. Manifest aggregation is small but invalidating CloudFront can take a few seconds."
  type        = number
  default     = 30
}

variable "environment_variables" {
  description = "Additional environment variables for the deployer Lambda."
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "create_kms_key" {
  description = "Whether to create a KMS key. Set to false (and pass kms_key_arn) when the key is provided from a parent."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN."
  type        = string
  default     = null
}

variable "tags" {
  description = "Required resource tags. Must include Environment, System, and Owner."
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.tags), "Environment"),
      contains(keys(var.tags), "System"),
      contains(keys(var.tags), "Owner")
    ])
    error_message = "tags must include Environment, System, and Owner."
  }
}
