variable "name" {
  description = "Fault monitor name. Used to derive the bucket, Firehose, and alarm names."
  type        = string
}

variable "event_bus_name" {
  description = "Subsystem event hub bus name."
  type        = string
}

variable "event_pattern" {
  description = "EventBridge pattern matching the subset of events to archive as faults. Defaults to `detail-type = ['fault']`, which matches the event envelope convention from Chapter 4."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Optional fault bucket name override. Defaults to the module name."
  type        = string
  default     = null
}

variable "retention_days" {
  description = "Object retention in days. 0 disables the expiration rule entirely (faults are forever)."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_days >= 0
    error_message = "retention_days must be >= 0."
  }
}

variable "noncurrent_retention_days" {
  description = "Days non-current versions are retained before being expired."
  type        = number
  default     = 30
}

variable "buffering_size" {
  description = "Firehose buffer size in MB."
  type        = number
  default     = 5

  validation {
    condition     = var.buffering_size >= 1 && var.buffering_size <= 128
    error_message = "buffering_size must be between 1 and 128 MB."
  }
}

variable "buffering_interval" {
  description = "Firehose buffer interval in seconds. Shorter than event_lake's default — faults should land in S3 promptly so they can be resubmitted."
  type        = number
  default     = 60

  validation {
    condition     = var.buffering_interval >= 60 && var.buffering_interval <= 900
    error_message = "buffering_interval must be between 60 and 900 seconds."
  }
}

variable "prefix" {
  description = "Object key prefix for delivered fault events."
  type        = string
  default     = "faults/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
}

variable "error_prefix" {
  description = "Object key prefix for Firehose error output."
  type        = string
  default     = "firehose-errors/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/!{firehose:error-output-type}/"
}

variable "alarm_evaluation_periods" {
  description = "Number of evaluation periods for the fault-arrival alarm. The alarm fires when any fault is delivered, so this only controls how long ALARM state persists."
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "Period in seconds for the fault-arrival alarm metric."
  type        = number
  default     = 60
}

variable "notification_emails" {
  description = "Email endpoints subscribed to the fault notification topic. Faults are high-signal events — on-call should hear about them."
  type        = list(string)
  default     = []
}

variable "alarm_actions" {
  description = "Additional alarm action ARNs (e.g. PagerDuty, Slack via Lambda). Receive notifications in parallel to the SNS topic this module creates."
  type        = list(string)
  default     = []
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
