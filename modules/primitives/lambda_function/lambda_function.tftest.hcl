mock_provider "aws" {
  # AWS provider 6.x validates IAM policy strings as JSON; the default mock value
  # ("mock-value") fails that check, so we override it with a syntactically valid
  # empty policy document.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_zip_contract" {
  command = plan

  variables {
    name      = "contract-handler"
    s3_bucket = "artefacts"
    s3_key    = "handler.zip"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_lambda_function.this.package_type == "Zip"
    error_message = "Lambda should default to ZIP package type."
  }

  assert {
    condition     = aws_kms_key.this[0].enable_key_rotation == true
    error_message = "Managed KMS key must have rotation enabled."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 30
    error_message = "Log group retention must be finite (default 30 days)."
  }

  assert {
    condition     = aws_sqs_queue.dlq[0].message_retention_seconds == 1209600
    error_message = "Managed DLQ must retain messages for the SQS 14-day maximum so failures can be investigated."
  }

  assert {
    condition     = aws_lambda_function.this.tracing_config[0].mode == "Active"
    error_message = "X-Ray tracing must default to Active."
  }
}

run "requires_tags" {
  command = plan

  variables {
    name      = "contract-handler"
    s3_bucket = "artefacts"
    s3_key    = "handler.zip"
    tags = {
      Environment = "test"
    }
  }

  expect_failures = [var.tags]
}

run "attaches_layers" {
  command = plan

  variables {
    name      = "contract-handler"
    s3_bucket = "artefacts"
    s3_key    = "handler.zip"
    layers    = ["arn:aws:lambda:eu-west-2:123456789012:layer:aws-otel-nodejs-arm64-ver-1-0-0:1"]
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = length(aws_lambda_function.this.layers) == 1 && tolist(aws_lambda_function.this.layers)[0] == "arn:aws:lambda:eu-west-2:123456789012:layer:aws-otel-nodejs-arm64-ver-1-0-0:1"
    error_message = "Provided layer ARNs must be attached to the function."
  }
}

run "rejects_unlimited_log_retention" {
  command = plan

  variables {
    name               = "contract-handler"
    s3_bucket          = "artefacts"
    s3_key             = "handler.zip"
    log_retention_days = 0
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.log_retention_days]
}
