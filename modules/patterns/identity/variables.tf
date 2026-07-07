variable "name" {
  description = "Identity provider name. Used for the user pool and derived resource names."
  type        = string
}

variable "clients" {
  description = "App clients keyed by a short name. type 'spa' creates a public client (no secret, authorisation-code flow - use PKCE in the app); type 'confidential' creates a client with a secret for server-side callers. callback_urls/logout_urls are required for clients that use the hosted UI."
  type = map(object({
    type                   = string
    callback_urls          = optional(list(string), [])
    logout_urls            = optional(list(string), [])
    oauth_scopes           = optional(list(string), ["openid", "email", "profile"])
    access_token_validity  = optional(number, 60) # minutes
    id_token_validity      = optional(number, 60) # minutes
    refresh_token_validity = optional(number, 30) # days
  }))

  validation {
    condition     = length(var.clients) > 0
    error_message = "Declare at least one client - the jwt_authorizer output needs an audience."
  }

  validation {
    condition     = alltrue([for client in values(var.clients) : contains(["spa", "confidential"], client.type)])
    error_message = "client.type must be 'spa' or 'confidential'."
  }
}

variable "hosted_ui_domain_prefix" {
  description = "Optional Cognito hosted UI domain prefix (must be unique within the region). When null, no hosted UI domain is created and clients must use the API-based auth flows."
  type        = string
  default     = null
}

variable "allow_self_sign_up" {
  description = "Whether users can register themselves. Off by default: an administrator (or an invitation flow) creates users. Turn on for consumer-facing apps."
  type        = bool
  default     = false
}

variable "mfa_configuration" {
  description = "MFA posture for the pool. OPTIONAL enables software-token MFA that users can enrol in; ON requires it; OFF disables it."
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, OPTIONAL, or ON."
  }
}

variable "password_minimum_length" {
  description = "Minimum password length. The complexity requirements (upper, lower, number, symbol) are always on."
  type        = number
  default     = 12

  validation {
    condition     = var.password_minimum_length >= 8 && var.password_minimum_length <= 99
    error_message = "password_minimum_length must be between 8 and 99."
  }
}

variable "deletion_protection" {
  description = "Whether the user pool is protected from deletion. Matches the library's DynamoDB posture: on by default, explicitly overridable."
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
