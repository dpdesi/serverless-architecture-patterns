data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  effective_kms_key_arn = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_arn
  bucket_name           = coalesce(var.bucket_name, var.name)
  firehose_name         = "${var.name}-delivery"
  default_event_pattern = jsonencode({
    detail-type = ["fault"]
  })
  effective_event_pattern = coalesce(var.event_pattern, local.default_event_pattern)
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description         = "KMS key for ${var.name} fault monitor"
  enable_key_rotation = true
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "Provide a kms_key_arn when create_kms_key is false."
    }
  }
}

resource "aws_sns_topic" "faults" {
  name              = "${var.name}-faults"
  kms_master_key_id = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.notification_emails)

  topic_arn = aws_sns_topic.faults.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = local.effective_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "fault-retention"
    status = "Enabled"

    filter {}

    dynamic "expiration" {
      for_each = var.retention_days == 0 ? [] : [var.retention_days]

      content {
        days = expiration.value
      }
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_retention_days
    }
  }
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.firehose_name}"
  retention_in_days = 30
  kms_key_id        = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "firehose" {
  name               = "${var.name}-firehose"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "firehose" {
  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    actions   = ["logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.firehose.arn}:log-stream:${aws_cloudwatch_log_stream.firehose.name}"]
  }

  statement {
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [local.effective_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "firehose" {
  name   = "${var.name}-firehose"
  role   = aws_iam_role.firehose.id
  policy = data.aws_iam_policy_document.firehose.json
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = local.firehose_name
  destination = "extended_s3"
  tags        = var.tags

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = local.effective_kms_key_arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.this.arn
    prefix              = var.prefix
    error_output_prefix = var.error_prefix
    buffering_size      = var.buffering_size
    buffering_interval  = var.buffering_interval
    compression_format  = "GZIP"
    kms_key_arn         = local.effective_kms_key_arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }
}

data "aws_iam_policy_document" "events_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  name               = "${var.name}-events"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "events" {
  statement {
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch"
    ]
    resources = [aws_kinesis_firehose_delivery_stream.this.arn]
  }
}

resource "aws_iam_role_policy" "events" {
  name   = "${var.name}-events"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events.json
}

resource "aws_sqs_queue" "rule_dlq" {
  name                      = "${var.name}-rule-dlq"
  kms_master_key_id         = local.effective_kms_key_arn
  message_retention_seconds = 1209600
  tags                      = var.tags
}

data "aws_iam_policy_document" "rule_dlq" {
  statement {
    sid       = "AllowEventBridgeSendMessage"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.rule_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.faults.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "rule_dlq" {
  queue_url = aws_sqs_queue.rule_dlq.url
  policy    = data.aws_iam_policy_document.rule_dlq.json
}

resource "aws_cloudwatch_event_rule" "faults" {
  name           = "${var.name}-faults"
  description    = "Routes fault events to the fault monitor Firehose for archival and resubmission."
  event_bus_name = var.event_bus_name
  event_pattern  = local.effective_event_pattern
  tags           = var.tags
}

resource "aws_cloudwatch_event_target" "faults" {
  rule           = aws_cloudwatch_event_rule.faults.name
  event_bus_name = var.event_bus_name
  target_id      = "firehose"
  arn            = aws_kinesis_firehose_delivery_stream.this.arn
  role_arn       = aws_iam_role.events.arn

  dead_letter_config {
    arn = aws_sqs_queue.rule_dlq.arn
  }
}

resource "aws_cloudwatch_event_target" "faults_topic" {
  rule           = aws_cloudwatch_event_rule.faults.name
  event_bus_name = var.event_bus_name
  target_id      = "sns"
  arn            = aws_sns_topic.faults.arn

  dead_letter_config {
    arn = aws_sqs_queue.rule_dlq.arn
  }
}

resource "aws_sns_topic_policy" "faults" {
  arn    = aws_sns_topic.faults.arn
  policy = data.aws_iam_policy_document.sns_topic.json
}

data "aws_iam_policy_document" "sns_topic" {
  statement {
    sid       = "AllowEventBridgePublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.faults.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.faults.arn]
    }
  }

  # Attaching a topic policy replaces the SNS default policy, which is what
  # normally lets same-account CloudWatch alarms publish - so the module's
  # own alarms must be granted explicitly.
  statement {
    sid       = "AllowCloudWatchAlarmsPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.faults.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:*"]
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "fault_arrival" {
  alarm_name          = "${var.name}-fault-arrival"
  alarm_description   = "Fires when any fault event matches the fault_monitor rule. Faults are high-signal: on-call should investigate immediately."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Invocations"
  namespace           = "AWS/Events"
  period              = var.alarm_period_seconds
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = concat([aws_sns_topic.faults.arn], var.alarm_actions)
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    RuleName     = aws_cloudwatch_event_rule.faults.name
    EventBusName = var.event_bus_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "${var.name}-rule-dlq-depth"
  alarm_description   = "Fires when the fault rule DLQ receives messages — indicates Firehose or SNS could not be reached for matched fault events."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_actions       = concat([aws_sns_topic.faults.arn], var.alarm_actions)
  treat_missing_data  = "notBreaching"
  tags                = var.tags

  dimensions = {
    QueueName = aws_sqs_queue.rule_dlq.name
  }
}
