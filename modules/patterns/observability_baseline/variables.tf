variable "name" {
  description = "Observability baseline name."
  type        = string
}

variable "lambda_functions" {
  description = "Lambda functions to monitor."
  type = map(object({
    function_name        = string
    timeout_seconds      = number
    reserved_concurrency = optional(number)
    dlq_queue_name       = optional(string)
  }))
  default = {}
}

variable "alarm_actions" {
  description = "Additional alarm action ARNs."
  type        = list(string)
  default     = []
}

variable "notification_emails" {
  description = "Optional email endpoints subscribed to the alarm topic."
  type        = list(string)
  default     = []
}

variable "create_dashboard" {
  description = "Whether to create a CloudWatch dashboard."
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

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key when kms_key_arn is null. Set to false (and pass kms_key_arn) when the key comes from a parent composition - Terraform cannot evaluate `kms_key_arn == null` in a count when the ARN is a computed reference that is not known until apply."
  type        = bool
  default     = true
}

variable "monitored_queues" {
  description = "Queue names to alarm on depth (ApproximateNumberOfMessagesVisible > 0), keyed by a stable identifier. Use for DLQs that do not belong to a monitored Lambda, such as EventBridge rule-target DLQs."
  type        = map(string)
  default     = {}
}
