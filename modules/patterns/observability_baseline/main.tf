locals {
  effective_kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
  alarm_actions         = concat([aws_sns_topic.alarms.arn], var.alarm_actions)
  adot_environment_variables = {
    AWS_LAMBDA_EXEC_WRAPPER             = "/opt/otel-handler"
    OTEL_PROPAGATORS                    = "tracecontext,baggage,xray"
    OTEL_TRACES_SAMPLER                 = "parentbased_traceidratio"
    OTEL_TRACES_SAMPLER_ARG             = "0.05"
    OPENTELEMETRY_COLLECTOR_CONFIG_FILE = "/opt/otel/config.yaml"
    POWERTOOLS_LOGGER_LOG_EVENT         = "false"
    POWERTOOLS_SERVICE_NAME             = var.name
    POWERTOOLS_TRACER_CAPTURE_RESPONSE  = "false"
    POWERTOOLS_TRACER_CAPTURE_ERROR     = "true"
    POWERTOOLS_METRICS_NAMESPACE        = var.name
  }
}

resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} observability resources"
  enable_key_rotation = true
  tags                = var.tags
}

resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.notification_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.lambda_functions

  alarm_name          = "${each.value.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    FunctionName = each.value.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.lambda_functions

  alarm_name          = "${each.value.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    FunctionName = each.value.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.lambda_functions

  alarm_name          = "${each.value.function_name}-duration-p99"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = each.value.timeout_seconds * 1000 * 0.8
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    FunctionName = each.value.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  for_each = {
    for key, function in var.lambda_functions : key => function
    if function.dlq_queue_name != null
  }

  alarm_name          = "${each.value.dlq_queue_name}-visible-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = local.alarm_actions
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    QueueName = each.value.dlq_queue_name
  }
}

resource "aws_cloudwatch_dashboard" "this" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = var.name
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 24
        height = 6
        properties = {
          title  = "Lambda errors and throttles"
          region = "default"
          metrics = flatten([
            for function in values(var.lambda_functions) : [
              ["AWS/Lambda", "Errors", "FunctionName", function.function_name],
              [".", "Throttles", ".", "."]
            ]
          ])
          stat = "Sum"
        }
      }
    ]
  })
}
