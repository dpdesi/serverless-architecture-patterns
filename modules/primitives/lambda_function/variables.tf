variable "name" {
  description = "Name of the Lambda function."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "name must be between 1 and 64 characters."
  }
}

variable "description" {
  description = "Human-readable description of the function."
  type        = string
  default     = "Managed by the serverless architecture patterns Lambda primitive."
}

variable "package_type" {
  description = "Lambda package type. Use Zip with S3 artefacts or Image with a container image URI."
  type        = string
  default     = "Zip"

  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be Zip or Image."
  }
}

variable "s3_bucket" {
  description = "S3 bucket containing the ZIP artefact. Required when package_type is Zip."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 object key containing the ZIP artefact. Required when package_type is Zip."
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Optional S3 object version for immutable ZIP deployments."
  type        = string
  default     = null
}

variable "image_uri" {
  description = "Container image URI. Required when package_type is Image."
  type        = string
  default     = null
}

variable "runtime" {
  description = "Lambda runtime for ZIP functions."
  type        = string
  default     = "nodejs20.x"
}

variable "handler" {
  description = "Lambda handler for ZIP functions."
  type        = string
  default     = "index.handler"
}

variable "architectures" {
  description = "Instruction set architectures for the function."
  type        = list(string)
  default     = ["arm64"]

  validation {
    condition     = alltrue([for architecture in var.architectures : contains(["arm64", "x86_64"], architecture)])
    error_message = "architectures may only contain arm64 or x86_64."
  }
}

variable "memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 256
}

variable "timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency. Use null to leave unreserved."
  type        = number
  default     = null
}

variable "environment_variables" {
  description = "Non-secret environment variables. Use SSM Parameter Store or Secrets Manager ARNs for secrets."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "Optional customer managed KMS key ARN for environment variable encryption and SQS DLQ encryption."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Whether the module creates its own KMS key. Set to false (and pass kms_key_arn) when the key is provided from a parent pattern or stack — Terraform cannot evaluate `kms_key_arn == null` in a count when the ARN is a computed reference that is not known until apply."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days. Must be a finite retention period — unlimited retention (0) is not permitted."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the finite retention periods CloudWatch Logs supports (1 to 3653 days); unlimited retention (0) is not permitted."
  }
}

variable "tracing_mode" {
  description = "X-Ray tracing mode."
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be Active or PassThrough."
  }
}

variable "create_dead_letter_queue" {
  description = "Whether to create an encrypted SQS dead-letter queue for async Lambda failures."
  type        = bool
  default     = true
}

variable "dead_letter_queue_arn" {
  description = "Existing dead-letter queue ARN. Takes precedence over create_dead_letter_queue."
  type        = string
  default     = null
}

variable "dead_letter_queue_retention_seconds" {
  description = "Retention for the managed DLQ when created. Defaults to 14 days, the SQS maximum, to maximise forensic window."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dead_letter_queue_retention_seconds >= 60 && var.dead_letter_queue_retention_seconds <= 1209600
    error_message = "dead_letter_queue_retention_seconds must be between 60 (1 minute) and 1209600 (14 days)."
  }
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the function may read."
  type        = list(string)
  default     = []
}

variable "parameter_arns" {
  description = "SSM Parameter Store parameter ARNs the function may read."
  type        = list(string)
  default     = []
}

variable "policy_statements" {
  description = "Additional least-privilege IAM statements for the execution role."
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "layers" {
  description = "Lambda layer ARNs to attach to the function, for example the ADOT instrumentation layer. The layer architecture must match the function (arm64 by default)."
  type        = list(string)
  default     = []
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
