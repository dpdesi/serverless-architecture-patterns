locals {
  effective_kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
  common_environment = merge(var.environment_variables, {
    EVENT_BUS_NAME = var.event_bus_name
    SERVICE_NAME   = var.name
  })
}

resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} ESG resources"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_sqs_queue" "egress_dlq" {
  name                      = "${var.name}-egress-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_sqs_queue" "egress" {
  name                       = "${var.name}-egress"
  kms_master_key_id          = local.effective_kms_key_arn
  visibility_timeout_seconds = var.timeout * 6
  message_retention_seconds  = var.message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.egress_dlq.arn
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

  name               = "${var.name}-egress"
  s3_bucket          = var.artefacts.egress.s3_bucket
  s3_key             = var.artefacts.egress.s3_key
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
    COMPONENT        = "egress"
    EGRESS_QUEUE_URL = aws_sqs_queue.egress.url
  })
  policy_statements = [
    {
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ]
      resources = [aws_sqs_queue.egress.arn]
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
  name           = "${var.name}-egress"
  description    = "Routes subsystem events to the ESG egress queue."
  event_bus_name = var.event_bus_name
  event_pattern  = var.external_event_pattern
  tags           = var.tags
}

resource "aws_cloudwatch_event_target" "egress" {
  rule           = aws_cloudwatch_event_rule.egress.name
  event_bus_name = var.event_bus_name
  target_id      = "egress-queue"
  arn            = aws_sqs_queue.egress.arn
}

data "aws_iam_policy_document" "egress_queue" {
  statement {
    sid     = "AllowEventBridgeSendMessage"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.egress.arn
    ]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.egress.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "egress" {
  queue_url = aws_sqs_queue.egress.url
  policy    = data.aws_iam_policy_document.egress_queue.json
}

resource "aws_lambda_event_source_mapping" "egress" {
  event_source_arn        = aws_sqs_queue.egress.arn
  function_name           = module.egress.function_arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}
