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
  description = "Domain name of the BFF API Gateway custom domain (e.g. api.app.example.com). When null, the CloudFront distribution serves only the SPA without an API origin."
  type        = string
  default     = null
}

variable "api_origin_path_pattern" {
  description = "Path pattern for the API origin behaviour."
  type        = string
  default     = "/api/*"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
