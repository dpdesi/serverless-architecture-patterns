locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} EventBridge bus"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_cloudwatch_event_bus" "this" {
  name               = var.name
  kms_key_identifier = local.effective_kms_key_arn
  tags               = var.tags
}

resource "aws_cloudwatch_event_bus_policy" "this" {
  count = var.policy_json == null ? 0 : 1

  event_bus_name = aws_cloudwatch_event_bus.this.name
  policy         = var.policy_json
}

resource "aws_cloudwatch_event_archive" "this" {
  count = var.archive == null ? 0 : 1

  name             = var.archive.name
  description      = var.archive.description
  event_source_arn = aws_cloudwatch_event_bus.this.arn
  event_pattern    = var.archive.event_pattern
  retention_days   = var.archive.retention_days
}
