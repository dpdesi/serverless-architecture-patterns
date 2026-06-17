locals {
  event_reactor_enabled  = var.mode == "event_reactor"
  step_functions_enabled = var.mode == "step_functions"
  effective_kms_key_arn  = var.create_kms_key && var.kms_key_arn == null ? aws_kms_key.this[0].arn : var.kms_key_arn
  table_name             = coalesce(var.table_name, "${var.name}-events")
  listener_artefact      = var.artefacts.listener == null ? { s3_bucket = "", s3_key = "" } : var.artefacts.listener
  trigger_artefact       = var.artefacts.trigger == null ? { s3_bucket = "", s3_key = "" } : var.artefacts.trigger
  state_machine_definition = coalesce(var.state_machine_definition, jsonencode({
    Comment = "Default no-op Control Service workflow"
    StartAt = "Accepted"
    States = {
      Accepted = {
        Type = "Succeed"
      }
    }
  }))
  common_environment = merge(var.environment_variables, {
    EVENT_BUS_NAME = var.event_bus_name
    SERVICE_NAME   = var.name
  })
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key && var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} Control Service resources"
  enable_key_rotation = true
  tags                = var.tags
}

module "table" {
  count  = local.event_reactor_enabled ? 1 : 0
  source = "../../primitives/dynamodb_table"

  name           = local.table_name
  hash_key       = "pk"
  range_key      = "sk"
  create_kms_key = false
  kms_key_arn    = local.effective_kms_key_arn
  attributes = [
    {
      name = "pk"
      type = "S"
    },
    {
      name = "sk"
      type = "S"
    }
  ]
  tags = var.tags
}

resource "aws_sqs_queue" "listener_dlq" {
  count = local.event_reactor_enabled ? 1 : 0

  name                      = "${var.name}-listener-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_sqs_queue" "listener" {
  count = local.event_reactor_enabled ? 1 : 0

  name                       = "${var.name}-listener"
  kms_master_key_id          = local.effective_kms_key_arn
  visibility_timeout_seconds = var.timeout * 6
  message_retention_seconds  = var.message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.listener_dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = var.tags
}

resource "aws_sqs_queue" "trigger_dlq" {
  count = local.event_reactor_enabled ? 1 : 0

  name                      = "${var.name}-trigger-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

module "listener" {
  count  = local.event_reactor_enabled ? 1 : 0
  source = "../../primitives/lambda_function"

  name   = "${var.name}-listener"
  layers = var.layers
  # ESM-invoked (synchronous): the primitive's async DLQ never receives
  # messages and its default name collides with the pattern-level DLQ.
  create_dead_letter_queue = false
  s3_bucket                = local.listener_artefact.s3_bucket
  s3_key                   = local.listener_artefact.s3_key
  runtime                  = var.runtime
  handler                  = var.handler
  memory_size              = var.memory_size
  timeout                  = var.timeout
  create_kms_key           = false
  kms_key_arn              = local.effective_kms_key_arn
  log_retention_days       = var.log_retention_days
  environment_variables = merge(local.common_environment, {
    COMPONENT  = "listener"
    TABLE_NAME = module.table[0].name
  })
  policy_statements = [
    {
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ]
      resources = [aws_sqs_queue.listener[0].arn]
    },
    {
      actions = [
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      resources = [module.table[0].arn]
    }
  ]
  tags = var.tags
}

module "trigger" {
  count  = local.event_reactor_enabled ? 1 : 0
  source = "../../primitives/lambda_function"

  name   = "${var.name}-trigger"
  layers = var.layers
  # ESM-invoked (synchronous): the primitive's async DLQ never receives
  # messages and its default name collides with the pattern-level DLQ.
  create_dead_letter_queue = false
  s3_bucket                = local.trigger_artefact.s3_bucket
  s3_key                   = local.trigger_artefact.s3_key
  runtime                  = var.runtime
  handler                  = var.handler
  memory_size              = var.memory_size
  timeout                  = var.timeout
  create_kms_key           = false
  kms_key_arn              = local.effective_kms_key_arn
  log_retention_days       = var.log_retention_days
  environment_variables = merge(local.common_environment, {
    COMPONENT  = "trigger"
    TABLE_NAME = module.table[0].name
  })
  policy_statements = [
    {
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ]
      resources = [module.table[0].stream_arn]
    },
    {
      actions   = ["events:PutEvents"]
      resources = [var.event_bus_arn]
    },
    {
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.trigger_dlq[0].arn]
    }
  ]
  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "listener" {
  count = local.event_reactor_enabled ? 1 : 0

  name           = "${var.name}-listener"
  event_bus_name = var.event_bus_name
  event_pattern  = var.event_pattern
  tags           = var.tags
}

resource "aws_sqs_queue" "listener_rule_dlq" {
  count = local.event_reactor_enabled ? 1 : 0

  name                      = "${var.name}-listener-rule-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_cloudwatch_event_target" "listener" {
  count = local.event_reactor_enabled ? 1 : 0

  rule           = aws_cloudwatch_event_rule.listener[0].name
  event_bus_name = var.event_bus_name
  target_id      = "listener-queue"
  arn            = aws_sqs_queue.listener[0].arn

  dead_letter_config {
    arn = aws_sqs_queue.listener_rule_dlq[0].arn
  }
}

data "aws_iam_policy_document" "listener_rule_dlq" {
  count = local.event_reactor_enabled ? 1 : 0

  statement {
    sid       = "AllowEventBridgeDeadLetter"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.listener_rule_dlq[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.listener[0].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "listener_rule_dlq" {
  count = local.event_reactor_enabled ? 1 : 0

  queue_url = aws_sqs_queue.listener_rule_dlq[0].url
  policy    = data.aws_iam_policy_document.listener_rule_dlq[0].json
}

data "aws_iam_policy_document" "listener_queue" {
  count = local.event_reactor_enabled ? 1 : 0

  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.listener[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.listener[0].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "listener" {
  count = local.event_reactor_enabled ? 1 : 0

  queue_url = aws_sqs_queue.listener[0].url
  policy    = data.aws_iam_policy_document.listener_queue[0].json
}

resource "aws_lambda_event_source_mapping" "listener" {
  count = local.event_reactor_enabled ? 1 : 0

  event_source_arn        = aws_sqs_queue.listener[0].arn
  function_name           = module.listener[0].function_arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "trigger" {
  count = local.event_reactor_enabled ? 1 : 0

  event_source_arn        = module.table[0].stream_arn
  function_name           = module.trigger[0].function_arn
  starting_position       = "TRIM_HORIZON"
  batch_size              = 100
  maximum_retry_attempts  = var.stream_max_retry_attempts
  function_response_types = ["ReportBatchItemFailures"]

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.trigger_dlq[0].arn
    }
  }
}

resource "aws_cloudwatch_log_group" "sfn" {
  count = local.step_functions_enabled ? 1 : 0

  name              = "/aws/vendedlogs/states/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.effective_kms_key_arn
  tags              = var.tags
}

data "aws_iam_policy_document" "states_assume_role" {
  count = local.step_functions_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "states" {
  count = local.step_functions_enabled ? 1 : 0

  name               = "${var.name}-states"
  assume_role_policy = data.aws_iam_policy_document.states_assume_role[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "states" {
  count = local.step_functions_enabled ? 1 : 0

  statement {
    actions   = ["events:PutEvents"]
    resources = [var.event_bus_arn]
  }

  statement {
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }

  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [local.effective_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "states" {
  count = local.step_functions_enabled ? 1 : 0

  name   = "${var.name}-states"
  role   = aws_iam_role.states[0].id
  policy = data.aws_iam_policy_document.states[0].json
}

resource "aws_sfn_state_machine" "this" {
  count = local.step_functions_enabled ? 1 : 0

  name       = var.name
  role_arn   = aws_iam_role.states[0].arn
  type       = var.workflow_type
  definition = local.state_machine_definition
  tags       = var.tags

  logging_configuration {
    include_execution_data = var.step_functions_include_execution_data
    level                  = var.step_functions_log_level
    log_destination        = "${aws_cloudwatch_log_group.sfn[0].arn}:*"
  }

  tracing_configuration {
    enabled = true
  }
}

data "aws_iam_policy_document" "events_assume_role" {
  count = local.step_functions_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events_start_execution" {
  count = local.step_functions_enabled ? 1 : 0

  name               = "${var.name}-events-start"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "events_start_execution" {
  count = local.step_functions_enabled ? 1 : 0

  name = "${var.name}-events-start"
  role = aws_iam_role.events_start_execution[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.this[0].arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "workflow" {
  count = local.step_functions_enabled ? 1 : 0

  name           = "${var.name}-workflow"
  event_bus_name = var.event_bus_name
  event_pattern  = var.event_pattern
  tags           = var.tags
}

resource "aws_sqs_queue" "workflow_rule_dlq" {
  count = local.step_functions_enabled ? 1 : 0

  name                      = "${var.name}-workflow-rule-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_cloudwatch_event_target" "workflow" {
  count = local.step_functions_enabled ? 1 : 0

  rule           = aws_cloudwatch_event_rule.workflow[0].name
  event_bus_name = var.event_bus_name
  target_id      = "state-machine"
  arn            = aws_sfn_state_machine.this[0].arn
  role_arn       = aws_iam_role.events_start_execution[0].arn

  dead_letter_config {
    arn = aws_sqs_queue.workflow_rule_dlq[0].arn
  }
}

data "aws_iam_policy_document" "workflow_rule_dlq" {
  count = local.step_functions_enabled ? 1 : 0

  statement {
    sid       = "AllowEventBridgeDeadLetter"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.workflow_rule_dlq[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.workflow[0].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "workflow_rule_dlq" {
  count = local.step_functions_enabled ? 1 : 0

  queue_url = aws_sqs_queue.workflow_rule_dlq[0].url
  policy    = data.aws_iam_policy_document.workflow_rule_dlq[0].json
}

resource "aws_cloudwatch_metric_alarm" "executions_failed" {
  count = local.step_functions_enabled ? 1 : 0

  alarm_name          = "${var.name}-executions-failed"
  alarm_description   = "The ${var.name} workflow has failed executions."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.this[0].arn
  }
}

resource "aws_cloudwatch_metric_alarm" "executions_timed_out" {
  count = local.step_functions_enabled ? 1 : 0

  alarm_name          = "${var.name}-executions-timed-out"
  alarm_description   = "The ${var.name} workflow has timed-out executions."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsTimedOut"
  namespace           = "AWS/States"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.this[0].arn
  }
}

resource "terraform_data" "validate_kms_inputs" {
  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false - otherwise resources would be created without customer-managed encryption."
    }
  }
}
