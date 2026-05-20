package terraform.kms

import future.keywords.if
import future.keywords.in

encrypted_types := {
  "aws_dynamodb_table",
  "aws_sqs_queue",
  "aws_cloudwatch_log_group",
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in encrypted_types
  resource.mode == "managed"
  not has_encryption(resource)
  msg := sprintf("%s must use encryption", [resource.address])
}

has_encryption(resource) if {
  resource.type == "aws_dynamodb_table"
  resource.change.after.server_side_encryption[0].enabled
}

has_encryption(resource) if {
  resource.type == "aws_sqs_queue"
  resource.change.after.sqs_managed_sse_enabled
}

has_encryption(resource) if {
  resource.type == "aws_sqs_queue"
  resource.change.after.kms_master_key_id
}

has_encryption(resource) if {
  resource.type == "aws_cloudwatch_log_group"
  resource.change.after.retention_in_days > 0
}
