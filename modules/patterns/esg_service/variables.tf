variable "name" {
  description = "ESG service name."
  type        = string
}

variable "event_bus_name" {
  description = "Subsystem event hub bus name."
  type        = string
}

variable "event_bus_arn" {
  description = "Subsystem event hub bus ARN."
  type        = string
}

variable "artefacts" {
  description = "External Lambda artefacts for ingress and egress handlers."
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
  description = "EventBridge pattern for events that should be sent to the external system."
  type        = string
}

variable "create_webhook_api" {
  description = "Whether to expose the ingress Lambda through an HTTP API webhook endpoint."
  type        = bool
  default     = true
}

variable "jwt_authorizer" {
  description = "Optional JWT authoriser for the webhook API."
  type = object({
    issuer   = string
    audience = list(string)
  })
  default = null
}

variable "runtime" {
  description = "Lambda runtime for ZIP artefacts."
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
  default     = 256
}

variable "timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs used for external system credentials."
  type        = list(string)
  default     = []
}

variable "parameter_arns" {
  description = "SSM Parameter Store parameter ARNs used for external system configuration."
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Additional non-secret Lambda environment variables."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Retention for the egress queue. Defaults to 4 days; raise to widen the replay window for outbound calls."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Retention for the egress DLQ. Defaults to the 14-day SQS maximum so failed outbound payloads can be inspected."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "max_receive_count" {
  description = "Number of receives before the egress queue redrives a message to its DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
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

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key when kms_key_arn is null. Set to false (and pass kms_key_arn) when the key comes from a parent composition - Terraform cannot evaluate `kms_key_arn == null` in a count when the ARN is a computed reference that is not known until apply."
  type        = bool
  default     = true
}
