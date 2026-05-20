variable "name" {
  description = "DynamoDB table name."
  type        = string
}

variable "hash_key" {
  description = "Partition key attribute name."
  type        = string
}

variable "range_key" {
  description = "Optional sort key attribute name."
  type        = string
  default     = null
}

variable "attributes" {
  description = "DynamoDB attribute definitions."
  type = list(object({
    name = string
    type = string
  }))

  validation {
    condition     = alltrue([for attribute in var.attributes : contains(["S", "N", "B"], attribute.type)])
    error_message = "DynamoDB attribute types must be S, N, or B."
  }
}

variable "billing_mode" {
  description = "Billing mode."
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.billing_mode)
    error_message = "billing_mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "read_capacity" {
  description = "Read capacity for PROVISIONED tables."
  type        = number
  default     = null
}

variable "write_capacity" {
  description = "Write capacity for PROVISIONED tables."
  type        = number
  default     = null
}

variable "stream_enabled" {
  description = "Whether DynamoDB Streams are enabled."
  type        = bool
  default     = true
}

variable "stream_view_type" {
  description = "DynamoDB stream view type."
  type        = string
  default     = "NEW_AND_OLD_IMAGES"
}

variable "point_in_time_recovery_enabled" {
  description = "Whether point-in-time recovery is enabled."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "Whether deletion protection is enabled."
  type        = bool
  default     = true
}

variable "ttl" {
  description = "Optional TTL configuration."
  type = object({
    attribute_name = string
    enabled        = optional(bool, true)
  })
  default = null
}

variable "global_secondary_indexes" {
  description = "Global secondary index definitions."
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = optional(string, "ALL")
    read_capacity   = optional(number)
    write_capacity  = optional(number)
  }))
  default = []
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN for table encryption."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key. Set to false (and pass kms_key_arn) when the key is provided from a parent pattern or stack."
  type        = bool
  default     = true
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
