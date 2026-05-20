variable "system_name" {
  description = "System name."
  type        = string
}

variable "subsystem_name" {
  description = "Subsystem name."
  type        = string
}

variable "environment" {
  description = "Environment tier."
  type        = string
}

variable "owner" {
  description = "Owning team or group."
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region."
  type        = string
  default     = "eu-west-2"
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
