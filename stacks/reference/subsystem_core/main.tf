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
}

data "aws_region" "primary" {}

data "aws_region" "secondary" {
  provider = aws.secondary
}

module "event_hub" {
  source = "../../../modules/patterns/event_hub"

  name        = "${local.name_prefix}-hub"
  kms_key_arn = var.kms_key_arn
  routes = {
    customer_events = {
      event_pattern = jsonencode({
        source = ["${var.subsystem_name}.bff"]
      })
      targets = []
    }
  }
  tags = local.tags
}

module "customer_bff" {
  source = "../../../modules/patterns/bff_service"

  name           = "${local.name_prefix}-customer-bff"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  artefacts      = var.bff_artefacts
  table = {
    name = "${local.name_prefix}-customer"
  }
  jwt_authorizer = var.jwt_authorizer
  kms_key_arn    = var.kms_key_arn
  tags           = local.tags
}
