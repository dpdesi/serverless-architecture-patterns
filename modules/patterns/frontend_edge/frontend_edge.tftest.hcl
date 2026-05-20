mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Managed CloudFront policies are looked up by name; mock_provider needs a stable ID
  # so the distribution can reference them at plan time.
  mock_data "aws_cloudfront_cache_policy" {
    defaults = {
      id = "managed-policy-id"
    }
  }

  mock_data "aws_cloudfront_origin_request_policy" {
    defaults = {
      id = "managed-policy-id"
    }
  }
}

run "valid_single_origin_contract" {
  command = plan

  variables {
    name = "contract-edge"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.primary.block_public_policy
    error_message = "Primary origin bucket must block public bucket policies."
  }

  assert {
    condition     = aws_cloudfront_origin_access_control.primary.signing_behavior == "always"
    error_message = "Origin Access Control must always sign requests."
  }

  assert {
    condition     = local.default_target_origin == "primary"
    error_message = "When no secondary origin is provided the default cache behaviour must target the primary origin directly."
  }

  assert {
    condition     = aws_cloudfront_response_headers_policy.this.security_headers_config[0].strict_transport_security[0].include_subdomains == true
    error_message = "Default response headers policy must include HSTS with includeSubdomains."
  }
}

run "valid_dual_origin_contract" {
  command = plan

  variables {
    name = "contract-edge"
    secondary_origin = {
      domain_name              = "contract-edge-secondary.s3.us-west-2.amazonaws.com"
      origin_access_control_id = "OAC123456"
    }
    api_origins = {
      api = {
        domain_name  = "api.example.com"
        path_pattern = "/api/*"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = local.default_target_origin == "primary-secondary"
    error_message = "When a secondary origin is provided the default cache behaviour must target the origin group."
  }

  assert {
    condition     = local.api_enabled
    error_message = "api_origins must enable an ordered cache behaviour for the API path pattern."
  }
}

run "valid_multi_bff_contract" {
  command = plan

  variables {
    name = "contract-edge"
    api_origins = {
      catalogue = {
        domain_name  = "abc.execute-api.eu-west-2.amazonaws.com"
        path_pattern = "/catalogue/*"
      }
      cart = {
        domain_name  = "def.execute-api.eu-west-2.amazonaws.com"
        path_pattern = "/cart/*"
      }
      checkout = {
        domain_name  = "ghi.execute-api.eu-west-2.amazonaws.com"
        path_pattern = "/checkout/*"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = length(output.api_origin_ids) == 3
    error_message = "Each api_origins entry must produce one CloudFront origin id."
  }

  assert {
    condition     = output.api_origin_ids["catalogue"] == "api-catalogue"
    error_message = "Origin ids must follow the api-<key> convention so callers can attach additional behaviours by key."
  }
}

run "rejects_duplicate_path_patterns" {
  command = plan

  variables {
    name = "contract-edge"
    api_origins = {
      catalogue = {
        domain_name  = "abc.execute-api.eu-west-2.amazonaws.com"
        path_pattern = "/api/*"
      }
      cart = {
        domain_name  = "def.execute-api.eu-west-2.amazonaws.com"
        path_pattern = "/api/*"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.api_origins]
}

run "rejects_aliases_without_certificate" {
  command = plan

  variables {
    name           = "contract-edge"
    domain_aliases = ["app.example.com"]
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [aws_cloudfront_distribution.this]
}

run "rejects_non_us_east_1_certificate" {
  command = plan

  variables {
    name                = "contract-edge"
    acm_certificate_arn = "arn:aws:acm:eu-west-2:123456789012:certificate/abcd-efgh"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.acm_certificate_arn]
}
