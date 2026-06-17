variable "name" {
  description = "BFF service name."
  type        = string
}

variable "event_bus_name" {
  description = "Event hub bus name."
  type        = string
}

variable "event_bus_arn" {
  description = "Event hub bus ARN."
  type        = string
}

variable "artefacts" {
  description = "External Lambda artefact references. Source code is not packaged by this module."
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

variable "runtime" {
  description = "Lambda runtime for ZIP artefacts."
  type        = string
  default     = "nodejs20.x"
}

variable "handler" {
  description = "Lambda handler for ZIP artefacts."
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
  default     = 10
}

variable "table" {
  description = "Service table configuration."
  type = object({
    name      = string
    hash_key  = optional(string, "pk")
    range_key = optional(string, "sk")
    attributes = optional(list(object({
      name = string
      type = string
      })), [
      {
        name = "pk"
        type = "S"
      },
      {
        name = "sk"
        type = "S"
      }
    ])
  })
}

variable "jwt_authorizer" {
  description = "Optional HTTP API JWT authoriser."
  type = object({
    issuer   = string
    audience = list(string)
  })
  default = null
}

variable "cors_allow_origins" {
  description = "Allowed CORS origins."
  type        = list(string)
  default     = []
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
  description = "Retention for the listener queue. Defaults to 4 days; raise for long replay windows."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Retention for the listener and trigger DLQs. Defaults to the 14-day SQS maximum so failures can be investigated before they age out."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "max_receive_count" {
  description = "Number of receives before the listener queue redrives a message to its DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "stream_max_retry_attempts" {
  description = "Maximum retries for the DynamoDB Stream event source mapping before failed batches are written to the trigger DLQ. -1 means infinite (stream retention bounds the retry window)."
  type        = number
  default     = 10

  validation {
    condition     = var.stream_max_retry_attempts >= -1 && var.stream_max_retry_attempts <= 10000
    error_message = "stream_max_retry_attempts must be between -1 and 10000."
  }
}

variable "environment_variables" {
  description = "Additional non-secret Lambda environment variables."
  type        = map(string)
  default     = {}
}

variable "layers" {
  description = "Lambda layer ARNs to attach to every function this module creates, for example the ADOT instrumentation layer. The layer architecture must match the functions."
  type        = list(string)
  default     = []
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
