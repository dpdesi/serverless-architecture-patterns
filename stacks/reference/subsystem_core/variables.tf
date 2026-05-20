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
  description = "Primary AWS region."
  type        = string
  default     = "eu-west-2"
}

variable "secondary_region" {
  description = "Secondary AWS region for future multi-region support."
  type        = string
  default     = "eu-west-1"
}

variable "owner" {
  description = "Owning team or group."
  type        = string
}

variable "bff_artefacts" {
  description = "External artefacts for the customer BFF example."
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

variable "jwt_authorizer" {
  description = "Optional JWT authoriser for the BFF."
  type = object({
    issuer   = string
    audience = list(string)
  })
  default = null
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
