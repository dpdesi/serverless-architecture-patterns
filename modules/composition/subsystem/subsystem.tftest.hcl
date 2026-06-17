mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  manifest = {
    subsystem = "payouts"
    tags = {
      Environment = "test"
      System      = "payments"
      Owner       = "payouts-team"
    }
    artefact_defaults = {
      bucket = "payouts-artefacts-test"
      prefix = "lambda/"
    }
    bffs = [
      {
        name      = "initiation"
        path      = "/payouts/*"
        publishes = ["PayoutRequested"]
      },
      {
        name       = "tracking"
        path       = "/tracking/*"
        read_only  = true
        subscribes = ["PayoutApproved", "TransferSettled"]
      },
    ]
    controls = [
      {
        name       = "screening"
        mode       = "event_reactor"
        subscribes = ["PayoutRequested"]
      },
      {
        name       = "execution-saga"
        mode       = "step_functions"
        subscribes = ["PayoutApproved"]
      },
    ]
    esgs = [
      {
        name    = "banking-rails"
        egress  = ["TransferInstructed"]
        webhook = true
      },
    ]
    operations = {
      fault_monitor = { enabled = true }
      observability = { enabled = true }
    }
  }
}

run "composes_manifest_into_subsystem" {
  command = plan

  assert {
    condition     = output.subsystem == "payouts"
    error_message = "The subsystem name must come from the manifest."
  }

  assert {
    condition     = output.hub_route_keys == tolist(["event-lake", "tracking-inbound"])
    error_message = "The hub must get one inbound route per subscribing BFF plus the event-lake archive route - and nothing for BFFs without subscriptions."
  }

  assert {
    condition     = sort(keys(output.api_origins)) == sort(["initiation", "tracking"]) && output.api_origins["initiation"].path_pattern == "/payouts/*"
    error_message = "api_origins must contain every BFF that declares a path, keyed by BFF name with its path_pattern."
  }

  assert {
    condition = output.monitored_functions == tolist(sort([
      "initiation-rest", "initiation-listener", "initiation-trigger",
      "tracking-rest", "tracking-listener", "tracking-trigger",
      "screening-listener", "screening-trigger",
      "banking-rails-ingress", "banking-rails-egress",
    ]))
    error_message = "Observability must cover all BFF and ESG functions and reactor-mode control functions, but not step_functions sagas."
  }

  assert {
    condition     = aws_sqs_queue.route_dlq["tracking-inbound"].name == "payouts-hub-tracking-inbound-dlq"
    error_message = "Every composer-generated hub route must get a named, KMS-encrypted DLQ."
  }

  assert {
    condition     = length(aws_sqs_queue_policy.bff_listener) == 1
    error_message = "Each subscribing BFF listener queue must receive exactly one queue policy granting EventBridge delivery."
  }

  # The composer predicts hub rule ARNs to break a dependency cycle. If
  # event_hub ever renames its rules, this assertion fails here instead of
  # silently breaking EventBridge delivery in production.
  assert {
    condition     = alltrue([for k, name in output.hub_rule_names : name == "payouts-hub-${k}"])
    error_message = "Predicted hub rule names (used in the listener/DLQ queue policies) must match the names event_hub actually creates."
  }

  assert {
    condition     = length(local.monitored_queues) == 5
    error_message = "The composer must hand every off-Lambda DLQ (2 hub route DLQs + screening listener-rule DLQ + saga workflow-rule DLQ + banking-rails egress-rule DLQ) to observability for depth alarms."
  }

  assert {
    condition     = length(aws_iam_role.events_to_firehose) == 1
    error_message = "The EventBridge-to-Firehose glue role must exist when the event lake is enabled."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation == true
    error_message = "The subsystem key must have rotation enabled."
  }

  assert {
    condition     = length(local.adot_layers) == 0
    error_message = "ADOT must be off when no adot_layer_arn is set; functions then use X-Ray active tracing only."
  }
}

run "disabling_lake_removes_route_and_glue" {
  command = plan

  variables {
    manifest = {
      subsystem = "payouts"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "payouts-team"
      }
      artefact_defaults = { bucket = "payouts-artefacts-test" }
      bffs = [
        { name = "tracking", subscribes = ["PayoutApproved"] },
      ]
      operations = {
        event_lake = { enabled = false }
      }
    }
  }

  assert {
    condition     = output.hub_route_keys == tolist(["tracking-inbound"])
    error_message = "Disabling the event lake must remove the archive route."
  }

  assert {
    condition     = length(aws_iam_role.events_to_firehose) == 0
    error_message = "Disabling the event lake must remove the glue role."
  }

  assert {
    condition     = output.event_lake_bucket_name == null
    error_message = "event_lake_bucket_name must be null when the lake is disabled."
  }
}

run "ingress_only_esg_skips_egress_path" {
  command = plan

  variables {
    manifest = {
      subsystem = "callbacks"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "callbacks-team"
      }
      artefact_defaults = { bucket = "callbacks-artefacts-test" }
      controls = [
        { name = "processor", mode = "event_reactor", subscribes = ["PaymentStatusReceived"] },
      ]
      esgs = [
        { name = "psp-webhook", webhook = true },
      ]
      operations = {
        event_lake    = { enabled = false }
        observability = { enabled = true }
      }
    }
  }

  assert {
    condition     = output.monitored_functions == tolist(sort(["processor-listener", "processor-trigger", "psp-webhook-ingress"]))
    error_message = "An ingress-only ESG must contribute its ingress function to observability, and no egress function."
  }

  assert {
    condition     = !contains(keys(local.monitored_queues), "psp-webhook-egress-rule-dlq")
    error_message = "An ingress-only ESG has no egress rule DLQ to monitor."
  }
}

run "rejects_esg_with_neither_egress_nor_webhook" {
  command = plan

  variables {
    manifest = {
      subsystem = "callbacks"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "callbacks-team"
      }
      artefact_defaults = { bucket = "callbacks-artefacts-test" }
      esgs = [
        { name = "inert" },
      ]
    }
  }

  expect_failures = [var.manifest]
}

run "adot_layer_attaches_when_set" {
  command = plan

  variables {
    manifest = {
      subsystem = "callbacks"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "callbacks-team"
      }
      artefact_defaults = { bucket = "callbacks-artefacts-test" }
      bffs = [
        { name = "intake", path = "/intake/*", publishes = ["PaymentStatusReceived"] },
      ]
      operations = {
        event_lake = { enabled = false }
        observability = {
          enabled        = true
          adot_layer_arn = "arn:aws:lambda:eu-west-2:123456789012:layer:aws-otel-nodejs-arm64-ver-1-0-0:1"
        }
      }
    }
  }

  assert {
    condition     = local.adot_layers == tolist(["arn:aws:lambda:eu-west-2:123456789012:layer:aws-otel-nodejs-arm64-ver-1-0-0:1"])
    error_message = "A configured adot_layer_arn must be attached to every function as a layer."
  }

  assert {
    condition     = local.adot_env["AWS_LAMBDA_EXEC_WRAPPER"] == "/opt/otel-handler"
    error_message = "Enabling ADOT must add the OpenTelemetry exec wrapper to the function environment."
  }
}

run "rejects_invalid_control_mode" {
  command = plan

  variables {
    manifest = {
      subsystem = "payouts"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "payouts-team"
      }
      artefact_defaults = { bucket = "payouts-artefacts-test" }
      controls = [
        { name = "bad", mode = "lambda", subscribes = ["X"] },
      ]
    }
  }

  expect_failures = [var.manifest]
}

run "rejects_missing_artefact_sources" {
  command = plan

  variables {
    manifest = {
      subsystem = "payouts"
      tags = {
        Environment = "test"
        System      = "payments"
        Owner       = "payouts-team"
      }
      bffs = [
        { name = "initiation" },
      ]
    }
  }

  expect_failures = [var.manifest]
}
