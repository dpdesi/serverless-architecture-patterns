# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

A Terraform pattern library providing production-ready, reusable implementations of serverless architecture patterns for event-driven autonomous subsystems on AWS. It is a pattern catalogue and reference implementation — teams compose from it directly, use it as examples, or scaffold new serverless subsystem repositories from it.

**Terraform version:** >= 1.7, < 2.0 | **AWS Provider:** ~> 6.0

---

## Commands

### Validation & Formatting
```bash
terraform fmt -check -recursive     # Check formatting
./scripts/validate.sh               # Validate all example/stack roots (Linux/macOS)
.\scripts\validate.ps1              # Windows equivalent
```

### Testing
```bash
make test                                               # Run all module contract tests

# Run a single module's tests
terraform test ./modules/primitives/lambda_function
terraform test ./modules/primitives/api_http
terraform test ./modules/primitives/dynamodb_table
terraform test ./modules/primitives/eventbridge_bus
terraform test ./modules/patterns/observability_baseline
terraform test ./modules/patterns/event_hub
terraform test ./modules/patterns/bff_service
terraform test ./modules/patterns/esg_service
terraform test ./modules/patterns/control_service
terraform test ./modules/patterns/event_lake
terraform test ./modules/patterns/frontend_edge
terraform test ./modules/patterns/regional_health_check
terraform test ./modules/patterns/fault_monitor
terraform test ./modules/patterns/micro_frontend
```

### Policy & Security Gates
```bash
make policy     # OPA/conftest policy checks
make security   # Trivy HIGH/CRITICAL scan
```

### Smoke Tests (LocalStack)
```bash
make smoke                                            # Full LocalStack smoke test
docker compose up -d localstack                       # Start LocalStack manually
cd examples/subsystem-core/customer-subsystem && terraform init && terraform apply -auto-approve
```

---

## Architecture

### Two-Layer Module Structure

**Primitives** (`modules/primitives/`) — standardised single AWS resource wrappers that enforce security defaults:
- `lambda_function` — Lambda with KMS-encrypted logs, DLQ, one dedicated execution role, least-privilege defaults
- `api_http` — API Gateway v2 HTTP API with JWT auth, access logs, CORS, per-route Lambda permissions
- `dynamodb_table` — Streams, PITR, deletion protection, on-demand billing, KMS encryption
- `eventbridge_bus` — Custom EventBridge bus with KMS encryption and optional archive/replay

**Patterns** (`modules/patterns/`) — higher-order compositions of primitives forming complete subsystem concerns:
- `event_hub` — Central EventBridge bus; the nerve centre connecting all producers and consumers
- `bff_service` — Backend for Frontend: HTTP API + Lambda + DynamoDB with streams + SQS listener + event publishing
- `esg_service` — External Service Gateway: anti-corruption boundary for third-party integrations (ingress normalisation, egress queuing)
- `control_service` — Two modes: event-reactor (EventBridge rule → SQS → Lambda → micro event store) or Step Functions orchestration
- `event_lake` — Immutable S3 archive via Kinesis Firehose for audit, replay, and analytics
- `observability_baseline` — Shared alarms (errors/throttles/duration), SNS topic, dashboards, ADOT/Powertools env vars
- `frontend_edge` — CloudFront + private S3 origin (OAC), optional secondary-origin failover, optional API origin routing /api/* to a BFF, SPA error rewriting
- `regional_health_check` — Calculated Route 53 health check aggregating CloudWatch metric alarms per AWS dependency; composite alarm for human notification
- `fault_monitor` — Dedicated Firehose-to-S3 archive for `fault` events with SNS alerting and rule DLQ; pairs with the resubmission workflow described in Chapter 4
- `micro_frontend` — Manifest bucket + deployer Lambda that aggregates per-app `mfe.json` fragments into master `importmap/apps/mount-points` manifests; optional CloudFront invalidation

### Topology
```
Event Hub (EventBridge) ← central routing layer
   ├─ BFF Service         ← synchronous user intent, frontend state
   ├─ Control Service     ← observes events, emits decisions or orchestrates
   ├─ ESG Service         ← isolates external system concerns
   └─ Event Lake          ← archives selected facts for analytics/audit
         ↑ all wired through Observability Baseline for unified monitoring
```

### Reference Compositions
- `stacks/reference/` — Four reference stack templates: `subsystem_core`, `integration`, `records_analytics`, `public_app`
- `stacks/envs/` — Environment roots (dev/staging/prod via workspace aliases)
- `examples/` — Runnable minimal examples per pattern/primitive + LocalStack smoke path
- `templates/backstage/` — Backstage templates for scaffolding new subsystems and services

### Testing Strategy
Each module contains `.tftest.hcl` files running contract-level tests via `terraform test`. Policy gates use OPA Rego rules in `policies/opa/` (IAM, KMS, S3, tags). Security scanning via Trivy. LocalStack 3 provides the smoke-test environment.

### Security & Compliance Defaults (enforced across all modules)
- Customer-managed KMS encryption everywhere (DynamoDB, logs, EventBridge, SQS)
- One IAM execution role per Lambda (never shared)
- Finite CloudWatch log retention (never unlimited)
- Dead-letter queues on all async/event paths
- Secrets via SSM/Secrets Manager ARNs — never inlined in config
- DynamoDB: deletion protection + PITR always on
- S3: versioning + public-access block + lifecycle policies
- Child modules declare only `required_providers` — provider config lives in roots only
- Tags (Environment, System, Owner) are required and propagated

### CI Pipeline (`.github/workflows/ci.yml`)
Seven jobs run on every PR: `terraform fmt` → `terraform validate` → `terraform test` (parallel across 10 modules) → `tflint` → `conftest` OPA → `trivy` → LocalStack smoke test. All must pass (see `.github/required-checks.md`).
