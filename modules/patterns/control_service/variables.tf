variable "name" {
  description = "Control Service name."
  type        = string
}

variable "mode" {
  description = "Control Service mode: event_reactor or step_functions."
  type        = string
  default     = "event_reactor"

  validation {
    condition     = contains(["event_reactor", "step_functions"], var.mode)
    error_message = "mode must be event_reactor or step_functions."
  }
}

variable "event_bus_name" {
  description = "Subsystem event hub bus name."
  type        = string
}

variable "event_bus_arn" {
  description = "Subsystem event hub bus ARN."
  type        = string
}

variable "event_pattern" {
  description = "EventBridge pattern for lower-order events consumed by this service."
  type        = string
}

variable "artefacts" {
  description = "External Lambda artefacts for event_reactor mode."
  type = object({
    listener = optional(object({
      s3_bucket = string
      s3_key    = string
    }))
    trigger = optional(object({
      s3_bucket = string
      s3_key    = string
    }))
  })
  default = {}
}

variable "state_machine_definition" {
  description = "Amazon States Language definition for step_functions mode."
  type        = string
  default     = null
}

variable "workflow_type" {
  description = "Step Functions workflow type."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.workflow_type)
    error_message = "workflow_type must be STANDARD or EXPRESS."
  }
}

variable "table_name" {
  description = "Micro event store table name for event_reactor mode."
  type        = string
  default     = null
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
  description = "Retention for the listener queue in event_reactor mode."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Retention for the listener and trigger DLQs in event_reactor mode. Defaults to the 14-day SQS maximum."
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
  description = "Maximum retries for the micro event store DynamoDB Stream event source mapping before failures are written to the trigger DLQ. -1 means infinite (stream retention bounds the retry window)."
  type        = number
  default     = 10

  validation {
    condition     = var.stream_max_retry_attempts >= -1 && var.stream_max_retry_attempts <= 10000
    error_message = "stream_max_retry_attempts must be between -1 and 10000."
  }
}

variable "step_functions_log_level" {
  description = "CloudWatch Logs level for the Step Functions state machine. ALL captures every state transition; ERROR drops execution context and should only be used to silence very chatty workflows."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.step_functions_log_level)
    error_message = "step_functions_log_level must be ALL, ERROR, FATAL, or OFF."
  }
}

variable "step_functions_include_execution_data" {
  description = "Whether Step Functions logs include the execution input, output, and state data payloads. Disable only if payloads contain regulated data the log retention policy cannot hold."
  type        = bool
  default     = true
}

variable "environment_variables" {
  description = "Additional non-secret Lambda environment variables."
  type        = map(string)
  default     = {}
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

variable "alarm_actions" {
  description = "Actions (e.g. SNS topic ARNs) for the Step Functions execution alarms in step_functions mode."
  type        = list(string)
  default     = []
}
