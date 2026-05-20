mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_contract" {
  command = plan

  variables {
    name           = "contract-faults"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy
    error_message = "Fault bucket must block public bucket policies."
  }

  assert {
    condition     = aws_kinesis_firehose_delivery_stream.this.server_side_encryption[0].enabled
    error_message = "Firehose must encrypt delivery records with a customer managed CMK."
  }

  assert {
    condition     = aws_sqs_queue.rule_dlq.message_retention_seconds == 1209600
    error_message = "Rule DLQ must retain messages for the SQS 14-day maximum."
  }

  assert {
    condition     = local.effective_event_pattern == jsonencode({ detail-type = ["fault"] })
    error_message = "Default event pattern must match detail-type fault to align with the event envelope convention."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.fault_arrival.threshold == 0
    error_message = "Fault arrival alarm threshold must be 0 — any fault should page someone."
  }
}

run "custom_pattern_contract" {
  command = plan

  variables {
    name           = "contract-faults"
    event_bus_name = "contract-hub"
    event_bus_arn  = "arn:aws:events:eu-west-2:123456789012:event-bus/contract-hub"
    event_pattern = jsonencode({
      detail-type = ["fault", "poison"]
      source      = ["customer.bff"]
    })
    tags = {
      Environment = "test"
      System      = "contract"
      Owner       = "platform"
    }
  }

  assert {
    condition     = local.effective_event_pattern != jsonencode({ detail-type = ["fault"] })
    error_message = "Caller-provided event_pattern must override the default."
  }
}
