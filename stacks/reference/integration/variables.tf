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

variable "owner" {
  description = "Owning team or group."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region."
  type        = string
  default     = "eu-west-2"
}

variable "esg_artefacts" {
  description = "External artefacts for the ESG service."
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

variable "external_event_pattern" {
  description = "Pattern for events that should egress to the external system."
  type        = string
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
