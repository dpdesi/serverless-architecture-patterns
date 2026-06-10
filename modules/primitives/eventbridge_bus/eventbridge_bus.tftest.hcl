mock_provider "aws" {}

run "valid_bus_contract" {
  command = plan

  variables {
    name = "contract-bus"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_cloudwatch_event_bus.this.name == "contract-bus"
    error_message = "The custom event bus name should come from the module input."
  }

  assert {
    condition     = aws_kms_key.this[0].enable_key_rotation == true
    error_message = "Managed KMS key must have rotation enabled."
  }
}

run "archive_contract" {
  command = plan

  variables {
    name = "contract-bus"
    archive = {
      name           = "contract-bus-archive"
      retention_days = 30
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_cloudwatch_event_archive.this[0].retention_days == 30
    error_message = "The archive must use the retention period supplied by the caller."
  }
}

run "requires_tags" {
  command = plan

  variables {
    name = "contract-bus"
    tags = {
      System = "contract"
    }
  }

  expect_failures = [var.tags]
}
