mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_bff_contract" {
  command = plan

  variables {
    name           = "contract-customer-bff"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    artefacts = {
      rest = {
        s3_bucket = "artefacts"
        s3_key    = "rest.zip"
      }
      listener = {
        s3_bucket = "artefacts"
        s3_key    = "listener.zip"
      }
      trigger = {
        s3_bucket = "artefacts"
        s3_key    = "trigger.zip"
      }
    }
    table = {
      name = "contract-customer"
    }
    tags = {
      Environment = "test"
      System      = "customer"
      Owner       = "platform"
    }
  }

  assert {
    condition     = module.api.stage_name == "$default"
    error_message = "The BFF HTTP API should use the default stage unless callers customise the primitive directly."
  }

  assert {
    condition     = aws_sqs_queue.listener.redrive_policy != null
    error_message = "Listener queue must declare a redrive_policy so poison messages move to a DLQ instead of being dropped."
  }

  assert {
    condition     = aws_sqs_queue.listener_dlq.message_retention_seconds == 1209600
    error_message = "Listener DLQ must retain messages for the SQS 14-day maximum."
  }

  assert {
    condition     = aws_sqs_queue.trigger_dlq.message_retention_seconds == 1209600
    error_message = "Trigger DLQ must retain messages for the SQS 14-day maximum."
  }

  assert {
    condition     = length(aws_lambda_event_source_mapping.trigger.destination_config) == 1
    error_message = "Stream ESM must declare an on_failure destination so failed batches do not vanish when stream retention expires."
  }

  assert {
    condition     = aws_sqs_queue.trigger_dlq.name == "contract-customer-bff-trigger-dlq"
    error_message = "Trigger DLQ must be created so it can receive on_failure deliveries from the stream ESM."
  }
}
