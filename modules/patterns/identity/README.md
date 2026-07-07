# Identity Pattern

> **Full documentation:** [docs/patterns/identity.md](../../../docs/patterns/identity.md): what it builds, the client types, inputs and outputs, and when to use it.

The OpenID Connect provider the other patterns assume. Every `jwt_authorizer` input in the
library (`bff_service`, `esg_service`, `api_http`) validates tokens against an issuer and an
audience; this module is what provisions them: a Cognito user pool, its app clients, and an
optional hosted UI domain.

## What it builds

- An `aws_cognito_user_pool` with the library's security posture: deletion protection on,
  12-character minimum passwords with full complexity requirements, software-token MFA available
  (`OPTIONAL` by default), email as the username with verified-email recovery, and self sign-up
  **off** unless explicitly enabled.
- One `aws_cognito_user_pool_client` per entry in the `clients` map:
  - `type = "spa"`: a public client with no secret, for browser apps using the
    authorisation-code flow with PKCE.
  - `type = "confidential"`: a client with a secret, for server-side callers.
  - Clients with `callback_urls` get the hosted-UI code flow enabled; the implicit flow is never
    enabled. All clients hide username-existence errors and support token revocation.
- Optionally, an `aws_cognito_user_pool_domain` (hosted UI) when `hosted_ui_domain_prefix` is set.

## The output that matters

`jwt_authorizer` is shaped exactly for the rest of the library — pass it through unchanged:

```hcl
module "identity" {
  source = "../../modules/patterns/identity"

  name = "${local.name_prefix}-identity"
  clients = {
    web = {
      type          = "spa"
      callback_urls = ["https://app.example.com/callback"]
      logout_urls   = ["https://app.example.com/"]
    }
  }
  hosted_ui_domain_prefix = "${local.name_prefix}-auth"
  tags                    = local.tags
}

module "bff" {
  source = "../../modules/patterns/bff_service"
  # ...
  jwt_authorizer = module.identity.jwt_authorizer
}
```

## What's intentionally out of scope

- **Federation** (SAML/OIDC identity providers, social sign-in): add
  `aws_cognito_identity_provider` resources alongside this module and extend the clients'
  `supported_identity_providers` — the shape varies too much per organisation to hard-code here.
- **Cognito identity pools** (AWS-credential vending for browsers): a different concern from
  authenticating API calls; compose separately if the frontend needs direct AWS access.
- **Custom domains for the hosted UI**: needs an ACM certificate in us-east-1 and a DNS zone, both
  of which live at the stack level.
