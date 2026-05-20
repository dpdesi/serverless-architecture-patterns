provider "aws" {
  region = var.primary_region
}

locals {
  name_prefix = "${var.system_name}-${var.subsystem_name}-${var.environment}"
  tags = merge(var.tags, {
    Environment = var.environment
    System      = var.system_name
    Subsystem   = var.subsystem_name
    Owner       = var.owner
  })
}

module "event_lake" {
  source = "../../../modules/patterns/event_lake"

  name = "${local.name_prefix}-event-lake"
  tags = local.tags
}

module "observability" {
  source = "../../../modules/patterns/observability_baseline"

  name = "${local.name_prefix}-observability"
  tags = local.tags
}
