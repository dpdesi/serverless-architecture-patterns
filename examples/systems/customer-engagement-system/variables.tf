variable "primary_region" {
  description = "Primary AWS region for the example system."
  type        = string
  default     = "eu-west-2"
}

variable "system_name" {
  description = "System name used in resource names and tags."
  type        = string
  default     = "retail"
}

variable "subsystem_name" {
  description = "Subsystem name used in resource names and tags."
  type        = string
  default     = "customer-engagement"
}

variable "environment" {
  description = "Environment tier for the example."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owning team or group."
  type        = string
  default     = "platform"
}

variable "event_lake_bucket_name" {
  description = "S3 bucket for the event lake. Override before applying in a shared AWS account."
  type        = string
  default     = null
}

variable "bff_artefacts" {
  description = "Artefact references published by the BFF service build pipeline."
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

variable "control_artefacts" {
  description = "Artefact references published by the Control Service build pipeline."
  type = object({
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

variable "external_crm_artefacts" {
  description = "Artefact references published by the External CRM ESG build pipeline."
  type = object({
    ingress = object({
      s3_bucket = string
      s3_key    = string
    })
    egress = object({
      s3_bucket = string
      s3_key    = string
    })
  })
}

variable "external_crm_secret_arns" {
  description = "Secrets Manager ARNs used by the External CRM ESG."
  type        = list(string)
  default     = []
}

variable "external_crm_parameter_arns" {
  description = "SSM Parameter Store ARNs used by the External CRM ESG."
  type        = list(string)
  default     = []
}

variable "notification_emails" {
  description = "Optional email addresses for alarm notifications."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags merged with the required tags."
  type        = map(string)
  default     = {}
}
