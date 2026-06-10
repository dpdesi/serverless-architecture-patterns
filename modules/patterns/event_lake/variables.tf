variable "name" {
  description = "Event lake name."
  type        = string
}

variable "bucket_name" {
  description = "Optional explicit S3 bucket name."
  type        = string
  default     = null
}

variable "firehose_name" {
  description = "Optional Firehose delivery stream name."
  type        = string
  default     = null
}

variable "prefix" {
  description = "S3 prefix for delivered events."
  type        = string
  default     = "events/!{timestamp:yyyy}/!{timestamp:MM}/!{timestamp:dd}/"
}

variable "error_prefix" {
  description = "S3 prefix for failed Firehose deliveries."
  type        = string
  default     = "errors/!{firehose:error-output-type}/!{timestamp:yyyy}/!{timestamp:MM}/!{timestamp:dd}/"
}

variable "retention_days" {
  description = "Number of days to retain current event objects. Use 0 to disable expiry."
  type        = number
  default     = 2555
}

variable "noncurrent_retention_days" {
  description = "Number of days to retain non-current object versions."
  type        = number
  default     = 90
}

variable "object_lock_retention_days" {
  description = "S3 Object Lock default retention in days (GOVERNANCE mode). Objects cannot be deleted or overwritten within this window without bypass permission."
  type        = number
  default     = 30

  validation {
    condition     = var.object_lock_retention_days >= 1
    error_message = "object_lock_retention_days must be at least 1."
  }
}

variable "delivery_alarm_evaluation_periods" {
  description = "Evaluation periods for the Firehose delivery-failure alarm."
  type        = number
  default     = 3
}

variable "alarm_actions" {
  description = "Actions (e.g. SNS topic ARNs) for the Firehose delivery-failure alarm."
  type        = list(string)
  default     = []
}

variable "buffering_size" {
  description = "Firehose buffering size in MB."
  type        = number
  default     = 5
}

variable "buffering_interval" {
  description = "Firehose buffering interval in seconds."
  type        = number
  default     = 300
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

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key when kms_key_arn is null. Set to false (and pass kms_key_arn) when the key comes from a parent composition - Terraform cannot evaluate `kms_key_arn == null` in a count when the ARN is a computed reference that is not known until apply."
  type        = bool
  default     = true
}
