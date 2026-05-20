# Fault Monitor Pattern

Maps to Chapter 4 of *Software Architecture Patterns for Serverless Systems*: a dedicated archive
for `fault` events flowing on the subsystem event hub. Faults are the byproduct of stream
processors handling poison events — they need a separate persistent channel so the operator can
investigate root cause and resubmit the original payload once the upstream is fixed.

## What it builds

- An S3 bucket with public-access block, versioning, KMS encryption, and configurable retention.
- A Kinesis Firehose delivery stream writing GZIP-compressed records to that bucket, with its own
  CloudWatch log group and IAM role.
- An EventBridge rule on the subsystem hub (default pattern `{ "detail-type": ["fault"] }`) with
  two targets:
  - The Firehose stream for archival (so a CLI/Lambda can read faults and resubmit them).
  - An SNS topic so on-call hears about new faults synchronously.
- An SQS DLQ wired into both EventBridge targets so any delivery failure is preserved instead of
  silently dropped.
- A CloudWatch alarm that fires whenever the rule matches a single fault event (faults are
  high-signal — the alarm should be loud).
- A second CloudWatch alarm on the rule DLQ depth (in case Firehose or SNS itself is broken).

## What's intentionally out of scope

- **The resubmission worker.** The book references the [`aws-lambda-stream-cli`](https://github.com/jgilbert01/aws-lambda-stream-cli)
  utility which reads from the bucket and re-invokes the original function. That's an operator
  tool, not infrastructure — package it alongside your service code and grant it `s3:GetObject` on
  `bucket_arn` and `lambda:InvokeFunction` on your processors.
- **Generic event archival.** Use `event_lake` for the broad archive of business-fact events; this
  module is intentionally narrower (different retention, different alarms, smaller buffers).

## Composition

```hcl
module "fault_monitor" {
  source = "../../modules/patterns/fault_monitor"

  name           = "${local.name_prefix}-faults"
  event_bus_name = module.event_hub.bus_name
  event_bus_arn  = module.event_hub.bus_arn
  notification_emails = var.oncall_emails
  alarm_actions = [module.observability.alarm_topic_arn]
  tags = local.tags
}
```
