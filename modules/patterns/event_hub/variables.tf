variable "name" {
  description = "Subsystem event hub name."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN."
  type        = string
  default     = null
}

variable "archive_enabled" {
  description = "Whether to create an EventBridge archive for the hub."
  type        = bool
  default     = true
}

variable "archive_retention_days" {
  description = "Archive retention in days."
  type        = number
  default     = 30
}

variable "routes" {
  description = "EventBridge routing rules and targets."
  type = map(object({
    description   = optional(string)
    event_pattern = string
    enabled       = optional(bool, true)
    targets = list(object({
      id                       = string
      arn                      = string
      role_arn                 = optional(string)
      input_path               = optional(string)
      dead_letter_queue_arn    = optional(string)
      create_dead_letter_queue = optional(bool, true)
    }))
  }))
  default = {}
}

variable "pipes" {
  description = "Optional EventBridge Pipes for point-to-point integrations."
  type = map(object({
    source_arn     = string
    target_arn     = string
    role_arn       = string
    filter_pattern = optional(string)
    desired_state  = optional(string, "RUNNING")
  }))
  default = {}
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
