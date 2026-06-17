# Regional Health Check Pattern

> **Full documentation:** [docs/patterns/regional-health-check.md](../../../docs/patterns/regional-health-check.md): what it builds, the two aggregations, inputs and outputs, and when to use it.

Maps to Chapter 9 of *Software Architecture Patterns for Serverless Systems*: a calculated
Route 53 health check aggregating CloudWatch metric alarms that probe the AWS services a
subsystem depends on. When Route 53 decides the region is unhealthy, latency-based or failover
alias records route users to a peer region.

## What it builds

For each entry in `metric_alarms`:

- An `aws_cloudwatch_metric_alarm` evaluating the given namespace/metric in `var.region` against
  a threshold over `evaluation_periods * period` seconds.
- An `aws_route53_health_check` of type `CLOUDWATCH_METRIC` wrapping that alarm.

And once per module:

- An `aws_cloudwatch_composite_alarm` whose rule is the OR of every child alarm: pass its ARN
  to `alarm_actions` callers (e.g. the observability_baseline SNS topic) for human notification.
- An `aws_route53_health_check` of type `CALCULATED` whose `child_health_threshold` defaults to
  `len(metric_alarms)` (every child must be healthy) but can be relaxed for graceful degradation.

## What's intentionally out of scope

- The Route 53 record sets themselves: they live in the stack so they can mix in latency-based or
  failover routing across two regional instances of this module.
- The synthetic tracer flow described in the book (API → DDB → Stream → … → DDB update). That
  is application-level: the recommended Terraform-side setup is to point a CloudWatch Synthetics
  canary at your real API endpoints from the *opposite* region (so a Synthetics outage in this
  region cannot mask a real problem) and let that traffic drive these alarms.

## Typical inputs

```hcl
metric_alarms = {
  api_gateway_5xx = {
    namespace   = "AWS/ApiGateway"
    metric_name = "5XXError"
    dimensions  = { ApiName = "health-check-api" }
  }
  dynamodb_errors = {
    namespace   = "AWS/DynamoDB"
    metric_name = "SystemErrors"
    dimensions  = { TableName = "health-check-table" }
  }
  lambda_errors = {
    namespace   = "AWS/Lambda"
    metric_name = "Errors"
    dimensions  = { FunctionName = "health-check-tracer" }
  }
}
```

## Composition

- Pass `alarm_actions = [module.observability.alarm_topic_arn]` to fan out to your existing
  notification topic.
- Output `regional_health_check_id` is the value to feed into `aws_route53_record.health_check_id`
  on each regional alias.
