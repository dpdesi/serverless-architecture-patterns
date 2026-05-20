provider "aws" {
  region = var.primary_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  name_prefix = "${var.system_name}-${var.subsystem_name}-${var.environment}"
  tags = merge(var.tags, {
    Environment = var.environment
    System      = var.system_name
    Subsystem   = var.subsystem_name
    Owner       = var.owner
  })

  api_enabled = var.api_origin_domain_name != null

  adot_baseline = {
    AWS_LAMBDA_EXEC_WRAPPER             = "/opt/otel-handler"
    OTEL_PROPAGATORS                    = "tracecontext,baggage,xray"
    OTEL_TRACES_SAMPLER                 = "parentbased_traceidratio"
    OTEL_TRACES_SAMPLER_ARG             = "0.05"
    OPENTELEMETRY_COLLECTOR_CONFIG_FILE = "/opt/otel/config.yaml"
    POWERTOOLS_LOGGER_LOG_EVENT         = "false"
    POWERTOOLS_TRACER_CAPTURE_RESPONSE  = "false"
    POWERTOOLS_TRACER_CAPTURE_ERROR     = "true"
  }
}

data "aws_region" "primary" {}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "${local.name_prefix}-hub"
  routes = {
    public_app_facts = {
      event_pattern = jsonencode({
        source = ["${var.subsystem_name}.bff"]
      })
      targets = []
    }
  }
  tags = local.tags
}

module "bff" {
  source = "../../../modules/patterns/bff_service"

  name           = "${local.name_prefix}-bff"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  artefacts      = var.bff_artefacts
  table = {
    name = "${local.name_prefix}-public"
  }
  environment_variables = merge(local.adot_baseline, {
    OTEL_SERVICE_NAME            = "${local.name_prefix}-bff"
    POWERTOOLS_SERVICE_NAME      = "${local.name_prefix}-bff"
    POWERTOOLS_METRICS_NAMESPACE = "${local.name_prefix}-bff"
  })
  tags = local.tags
}

module "frontend_edge" {
  source = "../../../modules/patterns/frontend_edge"

  providers = {
    aws = aws.us_east_1
  }

  name                       = "${local.name_prefix}-edge"
  primary_origin_bucket_name = "${local.name_prefix}-edge-primary"

  api_origin = local.api_enabled ? {
    domain_name  = var.api_origin_domain_name
    path_pattern = var.api_origin_path_pattern
  } : null

  domain_aliases      = var.domain_aliases
  acm_certificate_arn = var.acm_certificate_arn

  tags = local.tags
}

module "micro_frontend" {
  source = "../../../modules/patterns/micro_frontend"

  providers = {
    aws = aws.us_east_1
  }

  name                           = "${local.name_prefix}-manifests"
  deployer_artefact              = var.manifest_deployer_artefact
  frontend_edge_distribution_id  = module.frontend_edge.distribution_id
  frontend_edge_distribution_arn = module.frontend_edge.distribution_arn
  tags                           = local.tags
}

module "fault_monitor" {
  source = "../../../modules/patterns/fault_monitor"

  name           = "${local.name_prefix}-faults"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  tags           = local.tags
}

module "regional_health_check" {
  source = "../../../modules/patterns/regional_health_check"

  providers = {
    aws = aws.us_east_1
  }

  name   = "${local.name_prefix}-health"
  region = data.aws_region.primary.region

  metric_alarms = {
    bff_lambda_errors = {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      dimensions  = { FunctionName = module.bff.lambda_function_names.rest }
    }
    bff_table_system_errors = {
      namespace   = "AWS/DynamoDB"
      metric_name = "SystemErrors"
      dimensions  = { TableName = module.bff.table_name }
    }
  }

  alarm_actions = [module.observability.alarm_topic_arn]

  tags = local.tags
}

module "observability" {
  source = "../../../modules/patterns/observability_baseline"

  name = "${local.name_prefix}-observability"
  lambda_functions = {
    bff_rest = {
      function_name   = module.bff.lambda_function_names.rest
      timeout_seconds = 10
    }
    bff_listener = {
      function_name   = module.bff.lambda_function_names.listener
      timeout_seconds = 10
      dlq_queue_name  = module.bff.listener_dlq_name
    }
    bff_trigger = {
      function_name   = module.bff.lambda_function_names.trigger
      timeout_seconds = 10
      dlq_queue_name  = module.bff.trigger_dlq_name
    }
    manifest_deployer = {
      function_name   = module.micro_frontend.deployer_function_name
      timeout_seconds = 30
    }
  }
  tags = local.tags
}
