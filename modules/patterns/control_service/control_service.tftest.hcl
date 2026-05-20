mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_step_functions_contract" {
  command = plan

  variables {
    name           = "contract-control"
    mode           = "step_functions"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    event_pattern = jsonencode({
      source = ["customer.bff"]
    })
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_sfn_state_machine.this[0].type == "STANDARD"
    error_message = "Control Service workflows should default to Standard."
  }

  assert {
    condition     = aws_sfn_state_machine.this[0].logging_configuration[0].level == "ALL"
    error_message = "Step Functions logging must default to ALL so state transitions are observable."
  }

  assert {
    condition     = aws_sfn_state_machine.this[0].logging_configuration[0].include_execution_data == true
    error_message = "Step Functions logging must include execution data by default."
  }
}

run "valid_event_reactor_contract" {
  command = plan

  variables {
    name           = "contract-control"
    mode           = "event_reactor"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    event_pattern = jsonencode({
      source = ["customer.bff"]
    })
    artefacts = {
      listener = {
        s3_bucket = "artefacts"
        s3_key    = "listener.zip"
      }
      trigger = {
        s3_bucket = "artefacts"
        s3_key    = "trigger.zip"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_sqs_queue.listener[0].redrive_policy != null
    error_message = "Listener queue must declare a redrive_policy in event_reactor mode."
  }

  assert {
    condition     = aws_sqs_queue.listener_dlq[0].message_retention_seconds == 1209600
    error_message = "Listener DLQ must retain messages for the SQS 14-day maximum."
  }

  assert {
    condition     = length(aws_lambda_event_source_mapping.trigger[0].destination_config) == 1
    error_message = "Stream ESM must declare an on_failure destination so failed batches do not vanish."
  }

  assert {
    condition     = aws_sqs_queue.trigger_dlq[0].name == "contract-control-trigger-dlq"
    error_message = "Trigger DLQ must be created so it can receive on_failure deliveries from the stream ESM."
  }
}
