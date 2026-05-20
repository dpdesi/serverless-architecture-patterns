mock_provider "aws" {}

run "valid_contract" {
  command = plan

  variables {
    name   = "contract-rhc"
    region = "eu-west-2"
    metric_alarms = {
      api_gateway_5xx = {
        namespace   = "AWS/ApiGateway"
        metric_name = "5XXError"
        dimensions  = { ApiName = "contract-api" }
      }
      dynamodb_errors = {
        namespace   = "AWS/DynamoDB"
        metric_name = "SystemErrors"
        dimensions  = { TableName = "contract-table" }
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = local.effective_threshold == 2
    error_message = "Default child_health_threshold must equal len(metric_alarms) so every constituent must be healthy."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.child["api_gateway_5xx"].evaluation_periods == 5
    error_message = "Default evaluation_periods must be 5 (matches the book's recommended dampening)."
  }

  assert {
    condition     = aws_route53_health_check.regional.type == "CALCULATED"
    error_message = "Regional health check must be a CALCULATED Route 53 health check."
  }

  assert {
    condition     = aws_cloudwatch_composite_alarm.regional.alarm_rule == "ALARM(\"contract-rhc-api_gateway_5xx\") OR ALARM(\"contract-rhc-dynamodb_errors\")"
    error_message = "Composite alarm rule must OR every child alarm so any unhealthy service flags the region as down."
  }
}

run "rejects_empty_metric_alarms" {
  command = plan

  variables {
    name          = "contract-rhc"
    region        = "eu-west-2"
    metric_alarms = {}
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  expect_failures = [var.metric_alarms]
}
