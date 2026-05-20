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

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name = "${local.name_prefix}-hub"
  tags = local.tags
}

module "esg" {
  source = "../../../modules/patterns/esg_service"

  name                   = "${local.name_prefix}-external-esg"
  event_bus_name         = module.event_hub.bus_name
  event_bus_arn          = module.event_hub.bus_arn
  artefacts              = var.esg_artefacts
  external_event_pattern = var.external_event_pattern
  tags                   = local.tags
}
