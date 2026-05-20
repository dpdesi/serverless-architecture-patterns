mock_provider "aws" {}

run "valid_observability_contract" {
  command = plan

  variables {
    name = "contract-observability"
    lambda_functions = {
      rest = {
        function_name   = "contract-rest"
        timeout_seconds = 10
        dlq_queue_name  = "contract-rest-dlq"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_sns_topic.alarms.name == "contract-observability-alarms"
    error_message = "The baseline should create the alarm topic."
  }
}
