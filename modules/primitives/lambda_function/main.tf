locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
  effective_dlq_arn     = var.dead_letter_queue_arn != null ? var.dead_letter_queue_arn : try(aws_sqs_queue.dlq[0].arn, null)
  is_zip                = var.package_type == "Zip"
  is_image              = var.package_type == "Image"
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} Lambda resources"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_sqs_queue" "dlq" {
  count = var.create_dead_letter_queue && var.dead_letter_queue_arn == null ? 1 : 0

  name                      = "${var.name}-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = var.dead_letter_queue_retention_seconds
  tags                      = var.tags
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid = "WriteLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  statement {
    sid = "WriteTraces"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords"
    ]
    # X-Ray Put* actions do not support resource-level ARNs; "*" is the only valid scope.
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = local.effective_dlq_arn == null ? [] : [local.effective_dlq_arn]

    content {
      sid       = "SendToDeadLetterQueue"
      actions   = ["sqs:SendMessage"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = length(var.secret_arns) == 0 ? [] : [var.secret_arns]

    content {
      sid       = "ReadSecrets"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = statement.value
    }
  }

  dynamic "statement" {
    for_each = length(var.parameter_arns) == 0 ? [] : [var.parameter_arns]

    content {
      sid       = "ReadParameters"
      actions   = ["ssm:GetParameter", "ssm:GetParameters"]
      resources = statement.value
    }
  }

  dynamic "statement" {
    for_each = [local.effective_kms_key_arn]

    content {
      sid       = "UseCustomerManagedKey"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = var.policy_statements

    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${var.name}-execution"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_lambda_function" "this" {
  function_name                  = var.name
  description                    = var.description
  role                           = aws_iam_role.this.arn
  package_type                   = var.package_type
  runtime                        = local.is_zip ? var.runtime : null
  handler                        = local.is_zip ? var.handler : null
  s3_bucket                      = local.is_zip ? var.s3_bucket : null
  s3_key                         = local.is_zip ? var.s3_key : null
  s3_object_version              = local.is_zip ? var.s3_object_version : null
  image_uri                      = local.is_image ? var.image_uri : null
  architectures                  = var.architectures
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions
  kms_key_arn                    = local.effective_kms_key_arn
  tags                           = var.tags

  dynamic "dead_letter_config" {
    for_each = local.effective_dlq_arn == null ? [] : [local.effective_dlq_arn]

    content {
      target_arn = dead_letter_config.value
    }
  }

  environment {
    variables = var.environment_variables
  }

  tracing_config {
    mode = var.tracing_mode
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.execution
  ]

  lifecycle {
    precondition {
      condition     = local.is_zip ? var.s3_bucket != null && var.s3_key != null : var.image_uri != null
      error_message = "Zip functions require s3_bucket and s3_key; Image functions require image_uri."
    }
  }
}
