mock_provider "aws" {}

run "valid_table_contract" {
  command = plan

  variables {
    name     = "contract-table"
    hash_key = "pk"
    attributes = [
      {
        name = "pk"
        type = "S"
      }
    ]
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_dynamodb_table.this.billing_mode == "PAY_PER_REQUEST"
    error_message = "DynamoDB tables should default to on-demand billing."
  }

  assert {
    condition     = aws_dynamodb_table.this.server_side_encryption[0].enabled == true
    error_message = "DynamoDB tables must enable server-side encryption with the customer managed key."
  }

  assert {
    condition     = aws_dynamodb_table.this.point_in_time_recovery[0].enabled == true
    error_message = "Point-in-time recovery must be enabled by default."
  }

  assert {
    condition     = aws_dynamodb_table.this.deletion_protection_enabled == true
    error_message = "Deletion protection must be enabled by default."
  }

  assert {
    condition     = aws_dynamodb_table.this.stream_enabled == true && aws_dynamodb_table.this.stream_view_type == "NEW_AND_OLD_IMAGES"
    error_message = "Streams must default to enabled with NEW_AND_OLD_IMAGES so database-first event publication works."
  }

  assert {
    condition     = aws_kms_key.this[0].enable_key_rotation == true
    error_message = "Managed KMS key must have rotation enabled."
  }
}

run "requires_tags" {
  command = plan

  variables {
    name     = "contract-table"
    hash_key = "pk"
    attributes = [
      {
        name = "pk"
        type = "S"
      }
    ]
    tags = {
      Environment = "test"
    }
  }

  expect_failures = [var.tags]
}
