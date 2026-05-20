mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_contract" {
  command = plan

  variables {
    name = "contract-mfe"
    deployer_artefact = {
      s3_bucket = "artefacts"
      s3_key    = "deployer.zip"
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy
    error_message = "Manifest bucket must block public bucket policies."
  }

  assert {
    condition     = !local.invalidation_enabled
    error_message = "Invalidation must be disabled when no frontend_edge_distribution_id is provided."
  }

  assert {
    condition     = aws_s3_bucket_notification.this.lambda_function[0].filter_prefix == "manifests/"
    error_message = "S3 notification must filter on the manifests prefix to avoid invoking the deployer on master writes."
  }
}

run "with_cloudfront_invalidation" {
  command = plan

  variables {
    name = "contract-mfe"
    deployer_artefact = {
      s3_bucket = "artefacts"
      s3_key    = "deployer.zip"
    }
    frontend_edge_distribution_id  = "E123ABC"
    frontend_edge_distribution_arn = "arn:aws:cloudfront::123456789012:distribution/E123ABC"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = local.invalidation_enabled
    error_message = "Providing a distribution ID must enable invalidation behaviour."
  }
}

run "rejects_id_without_arn" {
  command = plan

  variables {
    name = "contract-mfe"
    deployer_artefact = {
      s3_bucket = "artefacts"
      s3_key    = "deployer.zip"
    }
    frontend_edge_distribution_id = "E123ABC"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [terraform_data.validate_invalidation_inputs]
}
