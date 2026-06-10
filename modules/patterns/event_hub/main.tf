locals {
  effective_kms_key_arn = var.create_kms_key && var.kms_key_arn == null ? aws_kms_key.this[0].arn : var.kms_key_arn

  targets = flatten([
    for route_key, route in var.routes : [
      for target in route.targets : {
        key                      = "${route_key}/${target.id}"
        route_key                = route_key
        target_id                = target.id
        target_arn               = target.arn
        role_arn                 = target.role_arn
        input_path               = target.input_path
        dead_letter_queue_arn    = target.dead_letter_queue_arn
        create_dead_letter_queue = target.create_dead_letter_queue
      }
    ]
  ])

  targets_by_key = {
    for target in local.targets : target.key => target
  }
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key && var.kms_key_arn == null ? 1 : 0

  description         = "KMS key for ${var.name} event hub target queues"
  enable_key_rotation = true
  tags                = var.tags
}

module "bus" {
  source = "../../primitives/eventbridge_bus"

  name           = var.name
  create_kms_key = false
  kms_key_arn    = local.effective_kms_key_arn
  archive = var.archive_enabled ? {
    name           = "${var.name}-archive"
    retention_days = var.archive_retention_days
  } : null
  tags = var.tags
}

resource "aws_sqs_queue" "target_dlq" {
  for_each = {
    for key, target in local.targets_by_key : key => target
    if target.create_dead_letter_queue && target.dead_letter_queue_arn == null
  }

  name              = "${var.name}-${replace(replace(each.key, "/", "-"), "_", "-")}-dlq"
  kms_master_key_id = local.effective_kms_key_arn
  tags              = var.tags
}

resource "aws_cloudwatch_event_rule" "route" {
  for_each = var.routes

  name           = "${var.name}-${each.key}"
  description    = each.value.description
  event_bus_name = module.bus.name
  event_pattern  = each.value.event_pattern
  state          = each.value.enabled ? "ENABLED" : "DISABLED"
  tags           = var.tags
}

resource "aws_cloudwatch_event_target" "route" {
  for_each = local.targets_by_key

  rule           = aws_cloudwatch_event_rule.route[each.value.route_key].name
  event_bus_name = module.bus.name
  target_id      = each.value.target_id
  arn            = each.value.target_arn
  role_arn       = each.value.role_arn
  input_path     = each.value.input_path

  dead_letter_config {
    arn = each.value.create_dead_letter_queue && each.value.dead_letter_queue_arn == null ? aws_sqs_queue.target_dlq[each.key].arn : each.value.dead_letter_queue_arn
  }
}

resource "aws_pipes_pipe" "this" {
  for_each = var.pipes

  name          = "${var.name}-${each.key}"
  role_arn      = each.value.role_arn
  source        = each.value.source_arn
  target        = each.value.target_arn
  desired_state = each.value.desired_state
  tags          = var.tags

  dynamic "source_parameters" {
    for_each = each.value.filter_pattern == null ? [] : [each.value.filter_pattern]

    content {
      filter_criteria {
        filter {
          pattern = source_parameters.value
        }
      }
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
