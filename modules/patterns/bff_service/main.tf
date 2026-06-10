locals {
  effective_kms_key_arn = var.create_kms_key && var.kms_key_arn == null ? aws_kms_key.this[0].arn : var.kms_key_arn

  common_environment = merge(var.environment_variables, {
    EVENT_BUS_NAME = var.event_bus_name
    TABLE_NAME     = module.table.name
    SERVICE_NAME   = var.name
  })

  ddb_item_actions = [
    "dynamodb:BatchGetItem",
    "dynamodb:BatchWriteItem",
    "dynamodb:DeleteItem",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:Query",
    "dynamodb:UpdateItem"
  ]
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key && var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} BFF resources"
  enable_key_rotation = true
  tags                = var.tags
}

module "table" {
  source = "../../primitives/dynamodb_table"

  name           = var.table.name
  hash_key       = var.table.hash_key
  range_key      = var.table.range_key
  attributes     = var.table.attributes
  create_kms_key = false
  kms_key_arn    = local.effective_kms_key_arn
  tags           = var.tags
}

resource "aws_sqs_queue" "listener_dlq" {
  name                      = "${var.name}-listener-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

resource "aws_sqs_queue" "listener" {
  name                       = "${var.name}-listener"
  kms_master_key_id          = local.effective_kms_key_arn
  visibility_timeout_seconds = var.timeout * 6
  message_retention_seconds  = var.message_retention_seconds
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.listener_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = var.tags
}

resource "aws_sqs_queue" "trigger_dlq" {
  name                      = "${var.name}-trigger-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

module "rest" {
  source = "../../primitives/lambda_function"

  name               = "${var.name}-rest"
  s3_bucket          = var.artefacts.rest.s3_bucket
  s3_key             = var.artefacts.rest.s3_key
  runtime            = var.runtime
  handler            = var.handler
  memory_size        = var.memory_size
  timeout            = var.timeout
  create_kms_key     = false
  kms_key_arn        = local.effective_kms_key_arn
  log_retention_days = var.log_retention_days
  environment_variables = merge(local.common_environment, {
    COMPONENT = "rest"
  })
  policy_statements = [
    {
      actions   = local.ddb_item_actions
      resources = [module.table.arn, "${module.table.arn}/index/*"]
    },
    {
      actions   = ["events:PutEvents"]
      resources = [var.event_bus_arn]
    }
  ]
  tags = var.tags
}

module "listener" {
  source = "../../primitives/lambda_function"

  name = "${var.name}-listener"
  # ESM-invoked (synchronous): the primitive's async DLQ never receives
  # messages and its default name collides with the pattern-level DLQ.
  create_dead_letter_queue = false
  s3_bucket                = var.artefacts.listener.s3_bucket
  s3_key                   = var.artefacts.listener.s3_key
  runtime                  = var.runtime
  handler                  = var.handler
  memory_size              = var.memory_size
  timeout                  = var.timeout
  create_kms_key           = false
  kms_key_arn              = local.effective_kms_key_arn
  log_retention_days       = var.log_retention_days
  environment_variables = merge(local.common_environment, {
    COMPONENT = "listener"
  })
  policy_statements = [
    {
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage"
      ]
      resources = [aws_sqs_queue.listener.arn]
    },
    {
      actions   = local.ddb_item_actions
      resources = [module.table.arn, "${module.table.arn}/index/*"]
    }
  ]
  tags = var.tags
}

module "trigger" {
  source = "../../primitives/lambda_function"

  name = "${var.name}-trigger"
  # ESM-invoked (synchronous): the primitive's async DLQ never receives
  # messages and its default name collides with the pattern-level DLQ.
  create_dead_letter_queue = false
  s3_bucket                = var.artefacts.trigger.s3_bucket
  s3_key                   = var.artefacts.trigger.s3_key
  runtime                  = var.runtime
  handler                  = var.handler
  memory_size              = var.memory_size
  timeout                  = var.timeout
  create_kms_key           = false
  kms_key_arn              = local.effective_kms_key_arn
  log_retention_days       = var.log_retention_days
  environment_variables = merge(local.common_environment, {
    COMPONENT = "trigger"
  })
  policy_statements = [
    {
      actions = [
        "dynamodb:DescribeStream",
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:ListStreams"
      ]
      resources = [module.table.stream_arn]
    },
    {
      actions   = ["events:PutEvents"]
      resources = [var.event_bus_arn]
    },
    {
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.trigger_dlq.arn]
    }
  ]
  tags = var.tags
}

module "api" {
  source = "../../primitives/api_http"

  name = "${var.name}-api"
  cors = {
    allow_origins = var.cors_allow_origins
  }
  jwt_authorizer = var.jwt_authorizer
  routes = {
    proxy = {
      route_key            = "ANY /{proxy+}"
      lambda_function_arn  = module.rest.invoke_arn
      lambda_function_name = module.rest.function_name
    }
    root = {
      route_key            = "ANY /"
      lambda_function_arn  = module.rest.invoke_arn
      lambda_function_name = module.rest.function_name
    }
  }
  create_kms_key            = false
  kms_key_arn               = local.effective_kms_key_arn
  access_log_retention_days = var.log_retention_days
  tags                      = var.tags
}

resource "aws_lambda_event_source_mapping" "listener" {
  event_source_arn        = aws_sqs_queue.listener.arn
  function_name           = module.listener.function_arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "trigger" {
  event_source_arn        = module.table.stream_arn
  function_name           = module.trigger.function_arn
  starting_position       = "TRIM_HORIZON"
  batch_size              = 100
  maximum_retry_attempts  = var.stream_max_retry_attempts
  function_response_types = ["ReportBatchItemFailures"]

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.trigger_dlq.arn
    }
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
