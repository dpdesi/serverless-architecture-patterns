variable "name" {
  description = "Name of the custom EventBridge bus."
  type        = string
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for EventBridge bus encryption."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key. Set to false (and pass kms_key_arn) when the key is provided from a parent pattern or stack."
  type        = bool
  default     = true
}

variable "policy_json" {
  description = "Optional EventBridge bus resource policy JSON."
  type        = string
  default     = null
}

variable "archive" {
  description = "Optional EventBridge archive configuration."
  type = object({
    name           = string
    event_pattern  = optional(string)
    retention_days = optional(number, 30)
    description    = optional(string, "Event archive managed by Terraform.")
  })
  default = null
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
