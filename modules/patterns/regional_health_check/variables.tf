variable "name" {
  description = "Regional health check name. Used to derive alarm and Route 53 health check names."
  type        = string
}

variable "region" {
  description = "AWS region this health check evaluates. Used as the alarm `Region` for Route 53 CloudWatch metric health checks."
  type        = string
}

variable "metric_alarms" {
  description = "Map of CloudWatch metric alarms to use as child health checks. Each alarm fires when its namespace/metric exceeds `threshold` for `evaluation_periods * period` seconds in the alarm's region. Common entries: API Gateway 5XXError, DynamoDB SystemErrors, S3 5xxErrors, Lambda Errors. Set the dimensions to scope the alarm to specific resources."
  type = map(object({
    namespace           = string
    metric_name         = string
    statistic           = optional(string, "Sum")
    period              = optional(number, 60)
    evaluation_periods  = optional(number, 5)
    threshold           = optional(number, 0)
    comparison_operator = optional(string, "GreaterThanThreshold")
    unit                = optional(string)
    dimensions          = optional(map(string), {})
    description         = optional(string)
  }))

  validation {
    condition     = length(var.metric_alarms) > 0
    error_message = "Provide at least one metric_alarm. A regional health check must observe something concrete."
  }
}

variable "child_health_threshold" {
  description = "Number of child health checks that must be healthy for the calculated Route 53 health check to report healthy. Defaults to len(metric_alarms) so every alarm must be clean."
  type        = number
  default     = null
}

variable "inverted" {
  description = "When true the calculated Route 53 health check reports healthy when fewer than child_health_threshold children are healthy. Use this only for chaos-testing scenarios."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "SNS topic ARNs (or other supported targets) notified when the composite alarm transitions to ALARM. Pass the observability_baseline alarm topic here to fan out to the same audience as other operational alerts."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Targets notified when the composite alarm transitions to OK."
  type        = list(string)
  default     = []
}

variable "treat_missing_data" {
  description = "How CloudWatch should interpret missing data for the child alarms. `notBreaching` is safer for sporadic services; switch to `breaching` for services with steady invocation."
  type        = string
  default     = "notBreaching"

  validation {
    condition     = contains(["missing", "ignore", "breaching", "notBreaching"], var.treat_missing_data)
    error_message = "treat_missing_data must be missing, ignore, breaching, or notBreaching."
  }
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
