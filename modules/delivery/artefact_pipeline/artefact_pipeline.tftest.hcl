mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_bucket_only_contract" {
  command = plan

  variables {
    name = "contract-artefacts"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy
    error_message = "Artefact bucket must block public bucket policies."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on - superseded artefact versions are the rollback mechanism."
  }

  assert {
    condition     = length(aws_iam_role.publisher) == 0
    error_message = "No publisher role may be created without a github_oidc configuration."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration[0].noncurrent_days == 90
    error_message = "Superseded versions must expire after the default 90 days."
  }
}

run "valid_github_oidc_contract" {
  command = plan

  variables {
    name = "contract-artefacts"
    github_oidc = {
      repository = "example-org/payouts-subsystem"
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = length(aws_iam_role.publisher) == 1
    error_message = "A publisher role must be created when github_oidc is configured."
  }

  assert {
    condition     = local.oidc_subjects[0] == "repo:example-org/payouts-subsystem:*"
    error_message = "The default OIDC subject must scope the role to the given repository."
  }

  assert {
    condition     = aws_iam_role.publisher[0].name == "contract-artefacts-publisher"
    error_message = "The publisher role name must derive from the module name unless overridden."
  }
}

run "rejects_malformed_repository" {
  command = plan

  variables {
    name = "contract-artefacts"
    github_oidc = {
      repository = "not-a-repo-path"
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.github_oidc]
}
