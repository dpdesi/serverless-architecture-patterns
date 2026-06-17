provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

locals {
  name_prefix = "${var.system_name}-${var.subsystem_name}-${var.environment}"
  tags = merge(var.tags, {
    Environment = var.environment
    System      = var.system_name
    Subsystem   = var.subsystem_name
    Owner       = var.owner
  })

  event_lake_bucket_name = coalesce(var.event_lake_bucket_name, "${local.name_prefix}-events")

  # Powertools flags, meaningful with the active X-Ray tracing every function
  # already has. Kept in a local rather than read from module.observability to
  # avoid a producer->consumer cycle (observability_baseline consumes Lambda
  # function names from these patterns). Full OpenTelemetry (the exec wrapper and
  # OTel exporter) only runs when the ADOT layer is attached: pass
  # `layers = [<adot layer arn>]` to the pattern modules, which adds the wrapper.
  adot_baseline = {
    POWERTOOLS_LOGGER_LOG_EVENT        = "false"
    POWERTOOLS_TRACER_CAPTURE_RESPONSE = "false"
    POWERTOOLS_TRACER_CAPTURE_ERROR    = "true"
  }
}

# This example is a composition recipe. It does not build or upload Lambda code.
# In a real system, CI/CD publishes these artefacts first, then Terraform consumes
# the immutable S3 locations through var.bff_artefacts, var.control_artefacts,
# and var.external_crm_artefacts.

module "event_lake" {
  source = "../../../modules/patterns/event_lake"

  name        = "${local.name_prefix}-event-lake"
  bucket_name = local.event_lake_bucket_name
  tags        = local.tags
}

# EventBridge needs an IAM role when a rule writes to Firehose. This is glue
# between two building blocks: event_hub routes facts and event_lake stores them.
data "aws_iam_policy_document" "events_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events_to_firehose" {
  name               = "${local.name_prefix}-events-to-firehose"
  assume_role_policy = data.aws_iam_policy_document.events_assume_role.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "events_to_firehose" {
  name = "${local.name_prefix}-events-to-firehose"
  role = aws_iam_role.events_to_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = module.event_lake.delivery_stream_arn
      }
    ]
  })
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "${local.name_prefix}-hub"
  routes = {
    archive_customer_facts = {
      description = "Copies selected customer engagement facts to the event lake."
      event_pattern = jsonencode({
        source = [
          "customer.bff",
          "customer.control",
          "customer.external-crm"
        ]
      })
      targets = [
        {
          id       = "event-lake"
          arn      = module.event_lake.delivery_stream_arn
          role_arn = aws_iam_role.events_to_firehose.arn
        }
      ]
    }
  }
  tags = local.tags
}

# The BFF owns the frontend-facing API and read model. The three artefacts map to
# the API handler, inbound event listener, and table-stream event publisher.
module "customer_bff" {
  source = "../../../modules/patterns/bff_service"

  name           = "${local.name_prefix}-bff"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  artefacts      = var.bff_artefacts
  table = {
    name = "${local.name_prefix}-customers"
  }
  environment_variables = merge(local.adot_baseline, {
    OTEL_SERVICE_NAME            = "${local.name_prefix}-bff"
    POWERTOOLS_SERVICE_NAME      = "${local.name_prefix}-bff"
    POWERTOOLS_METRICS_NAMESPACE = "${local.name_prefix}-bff"
  })
  tags = local.tags
}

# The Control Service reacts to BFF-published events and derives decisions or
# higher-order events. This example uses event_reactor mode; a workflow variant
# would set mode = "step_functions" and provide a state machine definition.
module "customer_control" {
  source = "../../../modules/patterns/control_service"

  name           = "${local.name_prefix}-control"
  mode           = "event_reactor"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  event_pattern = jsonencode({
    source = ["customer.bff"]
  })
  artefacts  = var.control_artefacts
  table_name = "${local.name_prefix}-control-events"
  environment_variables = merge(local.adot_baseline, {
    OTEL_SERVICE_NAME            = "${local.name_prefix}-control"
    POWERTOOLS_SERVICE_NAME      = "${local.name_prefix}-control"
    POWERTOOLS_METRICS_NAMESPACE = "${local.name_prefix}-control"
  })
  tags = local.tags
}

# The ESG contains the external CRM boundary: webhook ingress, outbound queue,
# egress adapter, and permissions to read external-system configuration.
module "external_crm_esg" {
  source = "../../../modules/patterns/esg_service"

  name           = "${local.name_prefix}-external-crm-esg"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  artefacts      = var.external_crm_artefacts
  external_event_pattern = jsonencode({
    detail-type = ["CustomerUpdated", "MarketingConsentChanged"]
  })
  secret_arns    = var.external_crm_secret_arns
  parameter_arns = var.external_crm_parameter_arns
  environment_variables = merge(local.adot_baseline, {
    EXTERNAL_SYSTEM_NAME         = "external-crm"
    OTEL_SERVICE_NAME            = "${local.name_prefix}-external-crm-esg"
    POWERTOOLS_SERVICE_NAME      = "${local.name_prefix}-external-crm-esg"
    POWERTOOLS_METRICS_NAMESPACE = "${local.name_prefix}-external-crm-esg"
  })
  tags = local.tags
}

# Observability is composed after the services so it can monitor the actual
# Lambda function names exposed by each building block.
module "observability" {
  source = "../../../modules/patterns/observability_baseline"

  name = "${local.name_prefix}-observability"
  lambda_functions = {
    bff_rest = {
      function_name   = module.customer_bff.lambda_function_names.rest
      timeout_seconds = 10
    }
    bff_listener = {
      function_name   = module.customer_bff.lambda_function_names.listener
      timeout_seconds = 10
      dlq_queue_name  = module.customer_bff.listener_dlq_name
    }
    bff_trigger = {
      function_name   = module.customer_bff.lambda_function_names.trigger
      timeout_seconds = 10
      dlq_queue_name  = module.customer_bff.trigger_dlq_name
    }
    control_listener = {
      function_name   = module.customer_control.lambda_function_names.listener
      timeout_seconds = 15
      dlq_queue_name  = module.customer_control.listener_dlq_name
    }
    control_trigger = {
      function_name   = module.customer_control.lambda_function_names.trigger
      timeout_seconds = 15
      dlq_queue_name  = module.customer_control.trigger_dlq_name
    }
    esg_ingress = {
      function_name   = module.external_crm_esg.ingress_function_name
      timeout_seconds = 15
    }
    esg_egress = {
      function_name   = module.external_crm_esg.egress_function_name
      timeout_seconds = 15
      dlq_queue_name  = module.external_crm_esg.egress_dlq_name
    }
  }
  notification_emails = var.notification_emails
  tags                = local.tags
}
