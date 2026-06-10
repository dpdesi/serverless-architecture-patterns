variable "name" {
  description = "HTTP API name."
  type        = string
}

variable "description" {
  description = "HTTP API description."
  type        = string
  default     = "Managed by the serverless architecture patterns HTTP API primitive."
}

variable "cors" {
  description = "CORS configuration."
  type = object({
    allow_credentials = optional(bool, false)
    allow_headers     = optional(list(string), ["authorization", "content-type", "x-request-id"])
    allow_methods     = optional(list(string), ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"])
    allow_origins     = optional(list(string), [])
    expose_headers    = optional(list(string), [])
    max_age           = optional(number, 86400)
  })
  default = null
}

variable "jwt_authorizer" {
  description = "Optional JWT authoriser configuration. When null, routes default to no authorisation unless overridden."
  type = object({
    name             = optional(string, "jwt")
    issuer           = string
    audience         = list(string)
    identity_sources = optional(list(string), ["$request.header.Authorization"])
  })
  default = null
}

variable "routes" {
  description = "HTTP API Lambda proxy routes."
  type = map(object({
    route_key            = string
    lambda_function_arn  = string
    lambda_function_name = string
    authorisation_type   = optional(string)
    authorisation_scopes = optional(list(string), [])
  }))
  default = {}
}

variable "stage_name" {
  description = "Stage name."
  type        = string
  default     = "$default"
}

variable "auto_deploy" {
  description = "Whether the stage auto deploys changes."
  type        = bool
  default     = true
}

variable "access_log_retention_days" {
  description = "Access log retention in days. Must be a finite retention period - unlimited retention (0) is not permitted."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.access_log_retention_days)
    error_message = "access_log_retention_days must be one of the finite retention periods CloudWatch Logs supports (1 to 3653 days); unlimited retention (0) is not permitted."
  }
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN for API access logs."
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
