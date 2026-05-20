mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_event_hub_contract" {
  command = plan

  variables {
    name = "contract-hub"
    routes = {
      customer = {
        event_pattern = jsonencode({
          source = ["customer.bff"]
        })
        targets = [
          {
            id  = "audit"
            arn = "arn:aws:logs:eu-west-2:123456789012:log-group:audit"
          }
        ]
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = module.bus.name == "contract-hub"
    error_message = "The event hub should create the named custom bus."
  }
}
