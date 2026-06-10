package terraform.tags

import future.keywords.if
import future.keywords.in

required_tags := {"Environment", "System", "Owner"}

taggable_types := {
  "aws_apigatewayv2_api",
  "aws_apigatewayv2_stage",
  "aws_cloudwatch_composite_alarm",
  "aws_cloudwatch_event_bus",
  "aws_cloudwatch_event_rule",
  "aws_cloudwatch_log_group",
  "aws_cloudwatch_metric_alarm",
  "aws_dynamodb_table",
  "aws_iam_role",
  "aws_kms_key",
  "aws_kinesis_firehose_delivery_stream",
  "aws_lambda_function",
  "aws_pipes_pipe",
  "aws_route53_health_check",
  "aws_s3_bucket",
  "aws_sfn_state_machine",
  "aws_sns_topic",
  "aws_sqs_queue",
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.type in taggable_types
  not resource.change.after.tags
  msg := sprintf("%s.%s must define tags", [resource.type, resource.name])
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.mode == "managed"
  resource.type in taggable_types
  tags := resource.change.after.tags
  missing := required_tags - {tag | tags[tag]}
  count(missing) > 0
  msg := sprintf("%s.%s is missing required tags: %v", [resource.type, resource.name, missing])
}
