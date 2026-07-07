provider "aws" {
  region = "eu-west-2"
}

module "identity" {
  source = "../../../modules/patterns/identity"

  name = "example-identity"

  clients = {
    # Public client for the browser app: no secret, code flow + PKCE via the
    # hosted UI.
    web = {
      type          = "spa"
      callback_urls = ["https://app.example.com/callback"]
      logout_urls   = ["https://app.example.com/"]
    }

    # Confidential client for server-side callers (e.g. a back-office job
    # calling the BFF with client-credentials-style auth).
    backoffice = {
      type = "confidential"
    }
  }

  hosted_ui_domain_prefix = "example-identity-dev"

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

# Pass this object straight into any bff_service / esg_service / api_http
# `jwt_authorizer` input.
output "jwt_authorizer" {
  value = module.identity.jwt_authorizer
}

output "hosted_ui_base_url" {
  value = module.identity.hosted_ui_base_url
}
