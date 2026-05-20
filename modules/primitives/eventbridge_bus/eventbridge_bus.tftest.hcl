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
