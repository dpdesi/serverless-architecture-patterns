provider "aws" {
  region = "eu-west-2"
}

module "artefacts" {
  source = "../../../modules/delivery/artefact_pipeline"

  name = "example-payouts-artefacts"

  # Grants the named repository's GitHub Actions workflows (via OIDC id-token)
  # permission to publish artefacts into this bucket - and nothing else.
  github_oidc = {
    repository = "example-org/payouts-subsystem"
  }

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

# Goes into the manifest's artefact_defaults.bucket.
output "bucket_name" {
  value = module.artefacts.bucket_name
}

# The role the app repo's build workflow assumes to publish zips.
output "publisher_role_arn" {
  value = module.artefacts.publisher_role_arn
}
