locals {
  effective_kms_key_arn = var.create_kms_key && var.kms_key_arn == null ? aws_kms_key.this[0].arn : var.kms_key_arn
  egress_enabled        = var.external_event_pattern != null
  common_environment = merge(var.environment_variables, {
    EVENT_BUS_NAME = var.event_bus_name
    SERVICE_NAME   = var.name
  })
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key && var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} ESG resources"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_sqs_queue" "egress_dlq" {
  count = local.egress_enabled ? 1 : 0

  name                      = "${var.name}-egress-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_sqs_queue" "egress" {
  count = local.egress_enabled ? 1 : 0

  name                       = "${var.name}-egress"
  kms_master_key_id          = local.effective_kms_key_arn
  visibility_timeout_seconds = var.timeout * 6
  message_retention_seconds  = var.message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.egress_dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = var.tags
}

module "ingress" {
  source = "../../primitives/lambda_function"

  name               = "${var.name}-ingress"
  s3_bucket          = var.artefacts.ingress.s3_bucket
  s3_key             = var.artefacts.ingress.s3_key
  runtime            = var.runtime
  handler            = var.handler
  memory_size        = var.memory_size
  timeout            = var.timeout
  create_kms_key     = false
  kms_key_arn        = local.effective_kms_key_arn
  log_retention_days = var.log_retention_days
  secret_arns        = var.secret_arns
  parameter_arns     = var.parameter_arns
  environment_variables = merge(local.common_environment, {
    COMPONENT = "ingress"
  })
  policy_statements = [
    {
      actions   = ["events:PutEvents"]
      resources = [var.event_bus_arn]
    }
  ]
  tags = var.tags
}

module "egress" {
  source = "../../primitives/lambda_function"
  count  = local.egress_enabled ? 1 : 0

  name = "${var.name}-egress"
  # ESM-invoked (synchronous): the primitive's async DLQ never receives
  # messages and its default name collides with the pattern-level DLQ.
  create_dead_letter_queue = false
  s3_bucket                = var.artefacts.egress.s3_bucket
  s3_key                   = var.artefacts.egress.s3_key
  runtime                  = var.runtime
  handler                  = var.handler
  memory_size              = var.memory_size
  timeout                  = var.timeout
  create_kms_key           = false
  kms_key_arn              = local.effective_kms_key_arn
  log_retention_days       = var.log_retention_days
  secret_arns              = var.secret_arns
  parameter_arns           = var.parameter_arns
  environment_variables = merge(local.common_environment, {
    COMPONENT        = "egress"
    EGRESS_QUEUE_URL = aws_sqs_queue.egress[0].url
  })
  policy_statements = [
    {
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ]
      resources = [aws_sqs_queue.egress[0].arn]
    }
  ]
  tags = var.tags
}

module "webhook_api" {
  count  = var.create_webhook_api ? 1 : 0
  source = "../../primitives/api_http"

  name           = "${var.name}-webhook-api"
  jwt_authorizer = var.jwt_authorizer
  routes = {
    webhook = {
      route_key            = "POST /webhook"
      lambda_function_arn  = module.ingress.invoke_arn
      lambda_function_name = module.ingress.function_name
    }
  }
  create_kms_key            = false
  kms_key_arn               = local.effective_kms_key_arn
  access_log_retention_days = var.log_retention_days
  tags                      = var.tags
}

resource "aws_cloudwatch_event_rule" "egress" {
  count = local.egress_enabled ? 1 : 0

  name           = "${var.name}-egress"
  description    = "Routes subsystem events to the ESG egress queue."
  event_bus_name = var.event_bus_name
  event_pattern  = var.external_event_pattern
  tags           = var.tags
}

resource "aws_sqs_queue" "egress_rule_dlq" {
  count = local.egress_enabled ? 1 : 0

  name                      = "${var.name}-egress-rule-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_cloudwatch_event_target" "egress" {
  count = local.egress_enabled ? 1 : 0

  rule           = aws_cloudwatch_event_rule.egress[0].name
  event_bus_name = var.event_bus_name
  target_id      = "egress-queue"
  arn            = aws_sqs_queue.egress[0].arn

  dead_letter_config {
    arn = aws_sqs_queue.egress_rule_dlq[0].arn
  }
}

data "aws_iam_policy_document" "egress_rule_dlq" {
  count = local.egress_enabled ? 1 : 0

  statement {
    sid       = "AllowEventBridgeDeadLetter"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.egress_rule_dlq[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.egress[0].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "egress_rule_dlq" {
  count = local.egress_enabled ? 1 : 0

  queue_url = aws_sqs_queue.egress_rule_dlq[0].url
  policy    = data.aws_iam_policy_document.egress_rule_dlq[0].json
}

data "aws_iam_policy_document" "egress_queue" {
  count = local.egress_enabled ? 1 : 0

  statement {
    sid     = "AllowEventBridgeSendMessage"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.egress[0].arn
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.egress[0].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "egress" {
  count = local.egress_enabled ? 1 : 0

  queue_url = aws_sqs_queue.egress[0].url
  policy    = data.aws_iam_policy_document.egress_queue[0].json
}

resource "aws_lambda_event_source_mapping" "egress" {
  count = local.egress_enabled ? 1 : 0

  event_source_arn        = aws_sqs_queue.egress[0].arn
  function_name           = module.egress[0].function_arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

resource "terraform_data" "validate_kms_inputs" {
  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false - otherwise resources would be created without customer-managed encryption."
    }

    precondition {
      condition     = !local.egress_enabled || var.artefacts.egress != null
      error_message = "Provide artefacts.egress when external_event_pattern is set - the egress handler needs code."
    }

    precondition {
      condition     = local.egress_enabled || var.create_webhook_api
      error_message = "An ESG with no egress path (external_event_pattern = null) must expose the webhook API - otherwise the gateway has no way to interact with the external system at all."
    }
  }
}
