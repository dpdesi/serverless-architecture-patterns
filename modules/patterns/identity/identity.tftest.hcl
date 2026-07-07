mock_provider "aws" {}

run "valid_identity_contract" {
  command = plan

  variables {
    name = "contract-identity"
    clients = {
      web = {
        type          = "spa"
        callback_urls = ["https://app.example.com/callback"]
        logout_urls   = ["https://app.example.com/"]
      }
      backoffice = {
        type = "confidential"
      }
    }
    hosted_ui_domain_prefix = "contract-identity"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_cognito_user_pool.this.deletion_protection == "ACTIVE"
    error_message = "Deletion protection must default to ACTIVE, matching the library's data-store posture."
  }

  assert {
    condition     = aws_cognito_user_pool.this.password_policy[0].minimum_length == 12
    error_message = "Password minimum length must default to 12."
  }

  assert {
    condition = alltrue([
      aws_cognito_user_pool.this.password_policy[0].require_lowercase,
      aws_cognito_user_pool.this.password_policy[0].require_uppercase,
      aws_cognito_user_pool.this.password_policy[0].require_numbers,
      aws_cognito_user_pool.this.password_policy[0].require_symbols,
    ])
    error_message = "Password complexity requirements must always be on."
  }

  assert {
    condition     = aws_cognito_user_pool.this.mfa_configuration == "OPTIONAL"
    error_message = "MFA must default to OPTIONAL with software-token enrolment available."
  }

  assert {
    condition     = aws_cognito_user_pool.this.admin_create_user_config[0].allow_admin_create_user_only
    error_message = "Self sign-up must be off by default."
  }

  assert {
    condition     = !aws_cognito_user_pool_client.this["web"].generate_secret
    error_message = "SPA clients are public clients and must not carry a secret."
  }

  assert {
    condition     = aws_cognito_user_pool_client.this["backoffice"].generate_secret
    error_message = "Confidential clients must carry a secret."
  }

  assert {
    condition     = aws_cognito_user_pool_client.this["web"].prevent_user_existence_errors == "ENABLED"
    error_message = "Clients must not leak username existence through error responses."
  }

  assert {
    condition     = contains(aws_cognito_user_pool_client.this["web"].allowed_oauth_flows, "code")
    error_message = "Hosted-UI clients must use the authorisation-code flow (never implicit)."
  }

  assert {
    condition     = length(aws_cognito_user_pool_client.this["backoffice"].allowed_oauth_flows) == 0
    error_message = "Clients without callback URLs must not have OAuth flows enabled."
  }

  assert {
    condition     = aws_cognito_user_pool_domain.this[0].domain == "contract-identity"
    error_message = "The hosted UI domain must be created when a prefix is provided."
  }
}

run "rejects_empty_clients" {
  command = plan

  variables {
    name    = "contract-identity"
    clients = {}
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.clients]
}

run "rejects_unknown_client_type" {
  command = plan

  variables {
    name = "contract-identity"
    clients = {
      web = {
        type = "mobile"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.clients]
}

run "no_hosted_ui_without_prefix" {
  command = plan

  variables {
    name = "contract-identity"
    clients = {
      machine = {
        type = "confidential"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = length(aws_cognito_user_pool_domain.this) == 0
    error_message = "No hosted UI domain may be created without a prefix."
  }
}
