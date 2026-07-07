variable "name" {
  description = "Pipeline name. Used for the bucket (unless overridden) and the deploy role."
  type        = string
}

variable "bucket_name" {
  description = "Optional artefact bucket name override. Defaults to the module name."
  type        = string
  default     = null
}

variable "noncurrent_version_retention_days" {
  description = "Days a superseded artefact version is kept before expiring. Versioning is always on so a bad deploy can roll back to the previous zip; this bounds how long that window stays open."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "noncurrent_version_retention_days must be at least 1."
  }
}

variable "github_oidc" {
  description = "Optional GitHub Actions OIDC deploy role. When set, an IAM role is created that the given repository's workflows can assume via id-token to publish artefacts into the bucket. `repository` is org/repo; `subjects` defaults to every ref of that repository - tighten it to e.g. [\"repo:org/repo:ref:refs/heads/main\"] to restrict which refs may publish. `provider_arn` points at the account's existing token.actions.githubusercontent.com OIDC provider; when null it is derived from the account id (the provider must already exist - it is account-global and usually created once by scripts/iac-role.sh or an account baseline)."
  type = object({
    repository   = string
    subjects     = optional(list(string))
    provider_arn = optional(string)
    role_name    = optional(string)
  })
  default = null

  validation {
    condition     = var.github_oidc == null || can(regex("^[^/]+/[^/]+$", var.github_oidc.repository))
    error_message = "github_oidc.repository must be org/repo."
  }
}

variable "create_kms_key" {
  description = "Whether to create a KMS key for the bucket. Set to false (and pass kms_key_arn) when the key is provided from a parent."
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
