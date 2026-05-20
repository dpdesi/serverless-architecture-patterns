mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_esg_contract" {
  command = plan

  variables {
    name           = "contract-esg"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    external_event_pattern = jsonencode({
      source = ["customer.bff"]
    })
    artefacts = {
      ingress = {
        s3_bucket = "artefacts"
        s3_key    = "ingress.zip"
      }
      egress = {
        s3_bucket = "artefacts"
        s3_key    = "egress.zip"
      }
    }
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_sqs_queue.egress.name == "contract-esg-egress"
    error_message = "The ESG should create an egress queue."
  }

  assert {
    condition     = aws_sqs_queue.egress.redrive_policy != null
    error_message = "Egress queue must declare a redrive_policy so undeliverable payloads move to a DLQ."
  }

  assert {
    condition     = aws_sqs_queue.egress_dlq.message_retention_seconds == 1209600
    error_message = "Egress DLQ must retain messages for the SQS 14-day maximum."
  }
}
