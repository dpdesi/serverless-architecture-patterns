data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  m    = var.manifest
  name = local.m.subsystem
  tags = merge(try(local.m.tags, {}), { Subsystem = local.name })

  artefact_defaults = try(local.m.artefact_defaults, null)
  artefact_prefix   = local.artefact_defaults == null ? "" : try(local.artefact_defaults.prefix, "")

  bffs     = { for b in try(local.m.bffs, []) : b.name => b }
  controls = { for c in try(local.m.controls, []) : c.name => c }
  esgs     = { for e in try(local.m.esgs, []) : e.name => e }

  reactor_controls = { for k, c in local.controls : k => c if c.mode == "event_reactor" }
  saga_controls    = { for k, c in local.controls : k => c if c.mode == "step_functions" }

  operations     = try(local.m.operations, {})
  lake_enabled   = try(local.operations.event_lake.enabled, true)
  fault_enabled  = try(local.operations.fault_monitor.enabled, true)
  obs_enabled    = try(local.operations.observability.enabled, true)
  health_enabled = try(local.operations.regional_health.enabled, false)

  alarm_actions = local.obs_enabled ? [module.observability[0].alarm_topic_arn] : []

  # ADOT instrumentation. Set operations.observability.adot_layer_arn to the AWS
  # Distro for OpenTelemetry layer (matching the function architecture) to attach
  # it to every function and add the OTel exec wrapper. Off by default: without a
  # layer the exec wrapper has nothing to run, so functions use X-Ray active
  # tracing only.
  adot_layer_arn = try(local.operations.observability.adot_layer_arn, null)
  adot_layers    = local.adot_layer_arn == null ? [] : [local.adot_layer_arn]
  adot_env = local.adot_layer_arn == null ? {} : {
    AWS_LAMBDA_EXEC_WRAPPER            = "/opt/otel-handler"
    OTEL_PROPAGATORS                   = "tracecontext,baggage,xray"
    OTEL_TRACES_SAMPLER                = "parentbased_traceidratio"
    OTEL_TRACES_SAMPLER_ARG            = "0.05"
    POWERTOOLS_LOGGER_LOG_EVENT        = "false"
    POWERTOOLS_TRACER_CAPTURE_RESPONSE = "false"
    POWERTOOLS_TRACER_CAPTURE_ERROR    = "true"
  }

  bff_artefacts = { for k, b in local.bffs : k => {
    rest = {
      s3_bucket = try(b.artefacts.rest.bucket, local.artefact_defaults.bucket)
      s3_key    = try(b.artefacts.rest.key, "${local.artefact_prefix}${local.name}-${k}-rest.zip")
    }
    listener = {
      s3_bucket = try(b.artefacts.listener.bucket, local.artefact_defaults.bucket)
      s3_key    = try(b.artefacts.listener.key, "${local.artefact_prefix}${local.name}-${k}-listener.zip")
    }
    trigger = {
      s3_bucket = try(b.artefacts.trigger.bucket, local.artefact_defaults.bucket)
      s3_key    = try(b.artefacts.trigger.key, "${local.artefact_prefix}${local.name}-${k}-trigger.zip")
    }
  } }

  control_artefacts = { for k, c in local.reactor_controls : k => {
    listener = {
      s3_bucket = try(c.artefacts.listener.bucket, local.artefact_defaults.bucket)
      s3_key    = try(c.artefacts.listener.key, "${local.artefact_prefix}${local.name}-${k}-listener.zip")
    }
    trigger = {
      s3_bucket = try(c.artefacts.trigger.bucket, local.artefact_defaults.bucket)
      s3_key    = try(c.artefacts.trigger.key, "${local.artefact_prefix}${local.name}-${k}-trigger.zip")
    }
  } }

  esg_egress_enabled = { for k, e in local.esgs : k => length(try(e.egress, [])) > 0 }

  esg_artefacts = { for k, e in local.esgs : k => merge(
    {
      ingress = {
        s3_bucket = try(e.artefacts.ingress.bucket, local.artefact_defaults.bucket)
        s3_key    = try(e.artefacts.ingress.key, "${local.artefact_prefix}${local.name}-${k}-ingress.zip")
      }
    },
    local.esg_egress_enabled[k] ? {
      egress = {
        s3_bucket = try(e.artefacts.egress.bucket, local.artefact_defaults.bucket)
        s3_key    = try(e.artefacts.egress.key, "${local.artefact_prefix}${local.name}-${k}-egress.zip")
      }
    } : {}
  ) }
}

# ---------------------------------------------------------------------------
# Subsystem KMS key.
# One customer-managed key for every queue, table, topic, bucket and log in
# the subsystem. The key policy grants the EventBridge and CloudWatch service
# principals use of the key - without these grants, EventBridge cannot
# deliver into SSE-KMS queues (listener queues, rule DLQs) and alarms cannot
# publish to the encrypted SNS topics.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "EnableIamPolicies"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowEventBridgeUse"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarmsUse"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "AllowSnsUse"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # EventBridge must be able to describe the key to attach it to the bus,
  # and the DescribeKey grant must be condition-free.
  statement {
    sid       = "AllowEventBridgeDescribeKey"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }

  # EventBridge publishing to a CMK-encrypted SNS topic (the fault monitor's
  # notify target) uses the key via the SNS service, where aws:SourceAccount
  # is not present in the request context.
  statement {
    sid       = "AllowEventBridgeViaSns"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sns.${data.aws_region.current.region}.amazonaws.com"]
    }
  }

  # CloudWatch Logs needs key-policy access before a log group can be
  # associated with the key - IAM policies are not consulted for this.
  statement {
    sid       = "AllowCloudWatchLogsUse"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "this" {
  description         = "KMS key for the ${local.name} subsystem"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# Event hub and routes.
# Routes are derived from the manifest: one inbound route per subscribing
# BFF and one archive route to the event lake. Every route target gets a
# composer-managed DLQ with the queue policy EventBridge needs to actually
# deliver into it.
# ---------------------------------------------------------------------------

locals {
  subscribing_bffs = { for k, b in local.bffs : k => b if length(try(b.subscribes, [])) > 0 }

  hub_name = "${local.name}-hub"

  lake_detail_types = try(local.operations.event_lake.detail_types, null)
  lake_event_pattern = local.lake_detail_types == null ? jsonencode({
    source = [{ prefix = "" }]
  }) : jsonencode({ "detail-type" = local.lake_detail_types })

  bff_routes = { for k, b in local.subscribing_bffs : "${k}-inbound" => {
    description   = "Routes subscribed events to the ${k} BFF listener queue."
    event_pattern = jsonencode({ "detail-type" = b.subscribes })
    targets = [{
      id                       = "listener"
      arn                      = module.bff[k].listener_queue_arn
      dead_letter_queue_arn    = aws_sqs_queue.route_dlq["${k}-inbound"].arn
      create_dead_letter_queue = false
    }]
  } }

  lake_routes = local.lake_enabled ? { "event-lake" = {
    description   = "Archives subsystem facts to the event lake."
    event_pattern = local.lake_event_pattern
    targets = [{
      id                       = "firehose"
      arn                      = module.event_lake[0].delivery_stream_arn
      role_arn                 = aws_iam_role.events_to_firehose[0].arn
      dead_letter_queue_arn    = aws_sqs_queue.route_dlq["event-lake"].arn
      create_dead_letter_queue = false
    }]
  } } : {}

  hub_routes = merge(local.bff_routes, local.lake_routes)

  # Statically-known route keys, so DLQs can be created with for_each.
  hub_route_keys = merge(
    { for k, b in local.subscribing_bffs : "${k}-inbound" => true },
    local.lake_enabled ? { "event-lake" = true } : {},
  )

  # EventBridge rule ARNs are predictable: rule/<bus>/<rule-name>. Building
  # them avoids a dependency cycle between the hub (which needs target ARNs)
  # and the queue policies (which need rule ARNs).
  hub_rule_arns = { for k, _ in local.hub_route_keys :
    k => "arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/${local.hub_name}/${local.hub_name}-${k}"
  }
}

module "hub" {
  source = "../../patterns/event_hub"

  name                   = local.hub_name
  create_kms_key         = false
  kms_key_arn            = aws_kms_key.this.arn
  archive_enabled        = try(local.m.hub.archive, true)
  archive_retention_days = try(local.m.hub.archive_retention_days, 30)
  routes                 = local.hub_routes
  tags                   = local.tags
}

resource "aws_sqs_queue" "route_dlq" {
  for_each = local.hub_route_keys

  name                      = "${local.hub_name}-${each.key}-dlq"
  kms_master_key_id         = aws_kms_key.this.arn
  message_retention_seconds = 1209600
  tags                      = local.tags
}

data "aws_iam_policy_document" "route_dlq" {
  for_each = local.hub_route_keys

  statement {
    sid       = "AllowEventBridgeDeadLetter"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.route_dlq[each.key].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.hub_rule_arns[each.key]]
    }
  }
}

resource "aws_sqs_queue_policy" "route_dlq" {
  for_each = local.hub_route_keys

  queue_url = aws_sqs_queue.route_dlq[each.key].url
  policy    = data.aws_iam_policy_document.route_dlq[each.key].json
}

# EventBridge cannot deliver into a BFF listener queue without a queue
# policy - bff_service deliberately does not know about the hub, so the
# composition owns this glue.
data "aws_iam_policy_document" "bff_listener" {
  for_each = local.subscribing_bffs

  statement {
    sid       = "AllowEventBridgeSendMessage"
    actions   = ["sqs:SendMessage"]
    resources = [module.bff[each.key].listener_queue_arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.hub_rule_arns["${each.key}-inbound"]]
    }
  }
}

resource "aws_sqs_queue_policy" "bff_listener" {
  for_each = local.subscribing_bffs

  queue_url = module.bff[each.key].listener_queue_url
  policy    = data.aws_iam_policy_document.bff_listener[each.key].json
}

# ---------------------------------------------------------------------------
# Services.
# ---------------------------------------------------------------------------

module "bff" {
  source   = "../../patterns/bff_service"
  for_each = local.bffs

  name           = "${local.name}-${each.key}"
  event_bus_name = module.hub.bus_name
  event_bus_arn  = module.hub.bus_arn
  artefacts      = local.bff_artefacts[each.key]

  table = {
    name      = "${local.name}-${each.key}"
    hash_key  = try(each.value.table.hash_key, "pk")
    range_key = try(each.value.table.range_key, "sk")
    attributes = try(each.value.table.attributes, [
      { name = try(each.value.table.hash_key, "pk"), type = "S" },
      { name = try(each.value.table.range_key, "sk"), type = "S" },
    ])
  }

  jwt_authorizer     = try({ issuer = each.value.jwt.issuer, audience = each.value.jwt.audiences }, null)
  cors_allow_origins = try(each.value.cors_allow_origins, [])
  create_kms_key     = false
  kms_key_arn        = aws_kms_key.this.arn

  layers = local.adot_layers
  environment_variables = merge(local.adot_env, {
    POWERTOOLS_SERVICE_NAME      = "${local.name}-${each.key}"
    POWERTOOLS_METRICS_NAMESPACE = local.name
    OTEL_SERVICE_NAME            = "${local.name}-${each.key}"
  })

  tags = local.tags
}

module "control" {
  source   = "../../patterns/control_service"
  for_each = local.controls

  name           = "${local.name}-${each.key}"
  mode           = each.value.mode
  event_bus_name = module.hub.bus_name
  event_bus_arn  = module.hub.bus_arn
  event_pattern  = jsonencode({ "detail-type" = each.value.subscribes })

  artefacts                = each.value.mode == "event_reactor" ? local.control_artefacts[each.key] : {}
  state_machine_definition = try(jsonencode(each.value.state_machine_definition), null)
  alarm_actions            = local.alarm_actions

  create_kms_key = false
  kms_key_arn    = aws_kms_key.this.arn

  layers = local.adot_layers
  environment_variables = merge(local.adot_env, {
    POWERTOOLS_SERVICE_NAME      = "${local.name}-${each.key}"
    POWERTOOLS_METRICS_NAMESPACE = local.name
    OTEL_SERVICE_NAME            = "${local.name}-${each.key}"
  })

  tags = local.tags
}

module "esg" {
  source   = "../../patterns/esg_service"
  for_each = local.esgs

  name           = "${local.name}-${each.key}"
  event_bus_name = module.hub.bus_name
  event_bus_arn  = module.hub.bus_arn
  artefacts      = local.esg_artefacts[each.key]

  external_event_pattern = local.esg_egress_enabled[each.key] ? jsonencode({ "detail-type" = each.value.egress }) : null
  create_webhook_api     = try(each.value.webhook, false)
  jwt_authorizer         = try({ issuer = each.value.jwt.issuer, audience = each.value.jwt.audiences }, null)
  secret_arns            = try(each.value.secret_arns, [])
  parameter_arns         = try(each.value.parameter_arns, [])
  create_kms_key         = false
  kms_key_arn            = aws_kms_key.this.arn

  layers = local.adot_layers
  environment_variables = merge(local.adot_env, {
    POWERTOOLS_SERVICE_NAME      = "${local.name}-${each.key}"
    POWERTOOLS_METRICS_NAMESPACE = local.name
    OTEL_SERVICE_NAME            = "${local.name}-${each.key}"
  })

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Operations.
# ---------------------------------------------------------------------------

module "event_lake" {
  source = "../../patterns/event_lake"
  count  = local.lake_enabled ? 1 : 0

  name                       = "${local.name}-event-lake"
  bucket_name                = try(local.operations.event_lake.bucket_name, null)
  retention_days             = try(local.operations.event_lake.retention_days, 2555)
  object_lock_retention_days = try(local.operations.event_lake.object_lock_retention_days, 30)
  alarm_actions              = local.alarm_actions
  create_kms_key             = false
  kms_key_arn                = aws_kms_key.this.arn
  tags                       = local.tags
}

# Glue between two building blocks: EventBridge needs a role to put records
# onto the event lake's Firehose delivery stream.
data "aws_iam_policy_document" "events_assume_role" {
  count = local.lake_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events_to_firehose" {
  count = local.lake_enabled ? 1 : 0

  name               = "${local.name}-events-to-firehose"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role[0].json
  tags               = local.tags
}

data "aws_iam_policy_document" "events_to_firehose" {
  count = local.lake_enabled ? 1 : 0

  statement {
    actions   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
    resources = [module.event_lake[0].delivery_stream_arn]
  }
}

resource "aws_iam_role_policy" "events_to_firehose" {
  count = local.lake_enabled ? 1 : 0

  name   = "${local.name}-events-to-firehose"
  role   = aws_iam_role.events_to_firehose[0].id
  policy = data.aws_iam_policy_document.events_to_firehose[0].json
}

module "fault_monitor" {
  source = "../../patterns/fault_monitor"
  count  = local.fault_enabled ? 1 : 0

  name                = "${local.name}-faults"
  event_bus_name      = module.hub.bus_name
  event_bus_arn       = module.hub.bus_arn
  bucket_name         = try(local.operations.fault_monitor.bucket_name, null)
  notification_emails = try(local.operations.fault_monitor.emails, [])
  alarm_actions       = local.alarm_actions
  create_kms_key      = false
  kms_key_arn         = aws_kms_key.this.arn
  tags                = local.tags
}

locals {
  observed_bffs = merge([for k, b in local.bffs : {
    "${k}-rest" = {
      function_name   = module.bff[k].lambda_function_names.rest
      timeout_seconds = module.bff[k].timeout_seconds
    }
    "${k}-listener" = {
      function_name   = module.bff[k].lambda_function_names.listener
      timeout_seconds = module.bff[k].timeout_seconds
      dlq_queue_name  = module.bff[k].listener_dlq_name
    }
    "${k}-trigger" = {
      function_name   = module.bff[k].lambda_function_names.trigger
      timeout_seconds = module.bff[k].timeout_seconds
      dlq_queue_name  = module.bff[k].trigger_dlq_name
    }
  }]...)

  observed_controls = merge([for k, c in local.reactor_controls : {
    "${k}-listener" = {
      function_name   = module.control[k].lambda_function_names.listener
      timeout_seconds = module.control[k].timeout_seconds
      dlq_queue_name  = module.control[k].listener_dlq_name
    }
    "${k}-trigger" = {
      function_name   = module.control[k].lambda_function_names.trigger
      timeout_seconds = module.control[k].timeout_seconds
      dlq_queue_name  = module.control[k].trigger_dlq_name
    }
  }]...)

  observed_esgs = merge([for k, e in local.esgs : merge(
    {
      "${k}-ingress" = {
        function_name   = module.esg[k].ingress_function_name
        timeout_seconds = module.esg[k].timeout_seconds
      }
    },
    local.esg_egress_enabled[k] ? {
      "${k}-egress" = {
        function_name   = module.esg[k].egress_function_name
        timeout_seconds = module.esg[k].timeout_seconds
        dlq_queue_name  = module.esg[k].egress_dlq_name
      }
    } : {}
  )]...)

  observed_functions = merge(local.observed_bffs, local.observed_controls, local.observed_esgs)

  # DLQs that do not belong to a monitored Lambda: composer-managed hub route
  # DLQs plus the patterns' own rule-target DLQs. Without depth alarms on
  # these, failed EventBridge deliveries vanish silently.
  monitored_queues = merge(
    { for k, _ in local.hub_route_keys : "hub-${k}-dlq" => aws_sqs_queue.route_dlq[k].name },
    { for k, c in local.reactor_controls : "${k}-listener-rule-dlq" => module.control[k].listener_rule_dlq_name },
    { for k, c in local.saga_controls : "${k}-workflow-rule-dlq" => module.control[k].workflow_rule_dlq_name },
    { for k, e in local.esgs : "${k}-egress-rule-dlq" => module.esg[k].egress_rule_dlq_name if local.esg_egress_enabled[k] },
  )
}

module "observability" {
  source = "../../patterns/observability_baseline"
  count  = local.obs_enabled ? 1 : 0

  name                = "${local.name}-observability"
  lambda_functions    = local.observed_functions
  monitored_queues    = local.monitored_queues
  notification_emails = try(local.operations.observability.emails, [])
  create_dashboard    = try(local.operations.observability.dashboard, true)
  create_kms_key      = false
  kms_key_arn         = aws_kms_key.this.arn
  tags                = local.tags
}

module "regional_health" {
  source = "../../patterns/regional_health_check"
  count  = local.health_enabled && length(local.bffs) > 0 ? 1 : 0

  name   = "${local.name}-health"
  region = coalesce(try(local.operations.regional_health.region, null), data.aws_region.current.region)

  metric_alarms = merge([for k, b in local.bffs : {
    "${k}-lambda-errors" = {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      dimensions  = { FunctionName = module.bff[k].lambda_function_names.rest }
    }
    "${k}-table-system-errors" = {
      namespace   = "AWS/DynamoDB"
      metric_name = "SystemErrors"
      dimensions  = { TableName = module.bff[k].table_name }
    }
  }]...)

  alarm_actions = local.alarm_actions
  tags          = local.tags
}
