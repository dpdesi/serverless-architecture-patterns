data "aws_region" "current" {}

locals {
  hosted_ui_enabled = var.hosted_ui_domain_prefix != null
  issuer            = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

resource "aws_cognito_user_pool" "this" {
  name                = var.name
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = var.password_minimum_length
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  mfa_configuration = var.mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.mfa_configuration == "OFF" ? [] : [1]

    content {
      enabled = true
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = !var.allow_self_sign_up
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_client" "this" {
  for_each = var.clients

  name         = "${var.name}-${each.key}"
  user_pool_id = aws_cognito_user_pool.this.id

  # SPA clients are public: no secret; the app proves itself with PKCE.
  # Confidential clients (server-side callers) get a secret.
  generate_secret = each.value.type == "confidential"

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  allowed_oauth_flows_user_pool_client = length(each.value.callback_urls) > 0
  allowed_oauth_flows                  = length(each.value.callback_urls) > 0 ? ["code"] : []
  allowed_oauth_scopes                 = length(each.value.callback_urls) > 0 ? each.value.oauth_scopes : []
  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  supported_identity_providers         = ["COGNITO"]

  access_token_validity  = each.value.access_token_validity
  id_token_validity      = each.value.id_token_validity
  refresh_token_validity = each.value.refresh_token_validity

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Do not leak whether a username exists through error differences.
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
}

resource "aws_cognito_user_pool_domain" "this" {
  count = local.hosted_ui_enabled ? 1 : 0

  domain       = var.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}
