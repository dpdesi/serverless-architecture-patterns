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
