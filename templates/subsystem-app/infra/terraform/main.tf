locals {
  manifest = yamldecode(file("${path.module}/subsystem.yaml"))
}

provider "aws" {
  region = var.region
}

# CloudFront, ACM certificates and Route 53 health checks must live in
# us-east-1. Provider aliases can only be declared in a root, which is exactly
# why the composer cannot create the edge for you - this root does.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# The whole subsystem backend, from one manifest. Pin the library to a released
# tag - never track a moving branch in a deploy root.
module "subsystem" {
  source   = "git::https://github.com/dpdesi/serverless-architecture-patterns.git//modules/composition/subsystem?ref=v0.2.1"
  manifest = local.manifest
}

# --- edge slot (us-east-1) ---------------------------------------------------
# Dormant unless the manifest sets edge.enabled = true. A backend-only
# subsystem leaves this at count = 0; a subsystem with a public SPA lights it
# up from the same manifest, fed by the composer's api_origins output.
module "edge" {
  count     = try(local.manifest.edge.enabled, false) ? 1 : 0
  source    = "git::https://github.com/dpdesi/serverless-architecture-patterns.git//modules/patterns/frontend_edge?ref=v0.2.1"
  providers = { aws = aws.us_east_1 }

  name                = "${local.manifest.subsystem}-edge"
  api_origins         = module.subsystem.api_origins
  domain_aliases      = try(local.manifest.edge.aliases, [])
  acm_certificate_arn = try(local.manifest.edge.acm_certificate_arn, null)
  tags                = local.manifest.tags
}
