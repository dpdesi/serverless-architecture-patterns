# Public App Reference Stack

Composes the patterns needed to deliver a publicly-reachable single-page application backed by an
autonomous subsystem:

- `event_hub` — internal EventBridge bus carrying subsystem facts.
- `bff_service` — HTTP API + DynamoDB + listener/trigger Lambdas for user-facing state.
- `frontend_edge` — CloudFront distribution with a private S3 origin (OAC), optional API origin
  routing `/api/*` to the BFF custom domain, and SPA-friendly error rewriting.
- `micro_frontend` — manifest bucket + deployer Lambda + CloudFront invalidation, so each
  micro-app's CI/CD can publish independently.
- `fault_monitor` — dedicated Firehose-to-S3 channel for `fault` events with high-signal
  alarming.
- `regional_health_check` — Route 53 calculated health check + CloudWatch composite alarm
  watching the BFF Lambda and DynamoDB.
- `observability_baseline` — error/throttle/duration alarms and dashboards for every Lambda in
  this stack.

## Provider aliases

CloudFront and its ACM certificates must live in `us-east-1`. This stack declares an
`aws.us_east_1` provider alias used by `frontend_edge`, `micro_frontend`, and
`regional_health_check`. The default `aws` provider continues to hold the subsystem's primary
region.

```hcl
provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}
```

## Multi-region

This stack is single-region. To add a peer region:

1. Instantiate the stack twice (one per region) or split frontend_edge from the regional resources.
2. Set the secondary instance's `frontend_edge.secondary_origin` to point at the primary's
   `primary_origin_bucket_regional_domain_name` and `primary_origin_access_control_id` outputs.
3. Wire `regional_health_check.regional_health_check_id` from each instance into Route 53 alias
   records for latency-based or failover routing.

## What's intentionally not wired

- ACM certificate + Route 53 alias records. They depend on a hosted zone that lives outside this
  pattern library and would prevent the stack from being a self-contained demo. Pass
  `domain_aliases` + `acm_certificate_arn` when you have them.
