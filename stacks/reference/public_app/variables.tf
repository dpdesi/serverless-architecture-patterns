variable "system_name" {
  description = "System name."
  type        = string
}

variable "subsystem_name" {
  description = "Subsystem name."
  type        = string
}

variable "environment" {
  description = "Environment tier."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region for the BFF, event hub, fault monitor, and observability resources. CloudFront, ACM, and Route 53 health checks always live in us-east-1 via the aws.us_east_1 provider alias."
  type        = string
  default     = "eu-west-2"
}

variable "owner" {
  description = "Owning team or group."
  type        = string
}

variable "bff_artefacts" {
  description = "External artefacts for the BFF service that backs the public app."
  type = object({
    rest = object({
      s3_bucket = string
      s3_key    = string
    })
    listener = object({
      s3_bucket = string
      s3_key    = string
    })
    trigger = object({
      s3_bucket = string
      s3_key    = string
    })
  })
}

variable "manifest_deployer_artefact" {
  description = "External artefact for the micro-frontend manifest deployer Lambda."
  type = object({
    s3_bucket = string
    s3_key    = string
  })
}

variable "domain_aliases" {
  description = "Optional custom domains for the CloudFront distribution."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1, required when domain_aliases is set."
  type        = string
  default     = null
}

variable "api_origin_domain_name" {
  description = "Optional override domain for the BFF API origin (e.g. api.app.example.com when a custom domain fronts API Gateway). When null, CloudFront uses the BFF's raw execute-api domain - useful for dev, but you usually want a custom domain in production so callers do not see AWS infrastructure URLs."
  type        = string
  default     = null
}

variable "api_origin_path_pattern" {
  description = "Path pattern routed from CloudFront to the BFF origin."
  type        = string
  default     = "/api/*"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
