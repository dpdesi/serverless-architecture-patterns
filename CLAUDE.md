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
tflint --init && tflint --recursive # Lint (config in .tflint.hcl)
```

### Testing
```bash
make test   # Runs all 15 module contract tests

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
terraform test ./modules/composition/subsystem
```

### Policy & Security Gates
```bash
make policy     # OPA/conftest policy checks
make security   # Trivy HIGH/CRITICAL scan
```
The policy gate asserts both directions: fixtures in `tests/fixtures/pass` must pass and fixtures in `tests/fixtures/fail` must fail. When adding an OPA rule in `policies/opa/`, add fixtures to both directories.

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

**Composition** (`modules/composition/`) — the abstraction on top of the patterns:
- `subsystem` — Renders a whole autonomous subsystem from a declarative `subsystem.yaml` manifest (schema in `schema/subsystem.schema.json`); derives hub routes, SQS queue policies for EventBridge delivery, per-route DLQs, the events→Firehose glue role, KMS service grants, and observability inputs. Example: `examples/systems/payouts-subsystem`

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
- `examples/systems/customer-engagement-system/` — Complete system composition wiring event hub, BFF, Control Service, ESG, event lake, and observability baseline together
- `templates/backstage/` — Backstage templates for scaffolding new subsystems and services

### Testing Strategy
Each module contains `.tftest.hcl` files running contract-level tests via `terraform test`. Policy gates use OPA Rego rules in `policies/opa/` (IAM, KMS, S3, tags). Security scanning via Trivy. LocalStack 3 provides the smoke-test environment.

### Security & Compliance Defaults (enforced across all modules)
- Customer-managed KMS encryption everywhere (DynamoDB, logs, EventBridge, SQS, SNS, Firehose)
- One IAM execution role per Lambda (never shared)
- Finite CloudWatch log retention — enforced by variable validation, 0 (unlimited) is rejected
- Dead-letter queues on all async/event paths, including a dead_letter_config on every EventBridge rule target
- Secrets via SSM/Secrets Manager ARNs — never inlined in config
- DynamoDB: deletion protection + PITR enabled by default (explicitly overridable per table)
- S3: versioning + public-access block + lifecycle policies; the event lake bucket also has Object Lock (GOVERNANCE) for immutability
- Child modules declare only `required_providers` — provider config lives in roots only
- Tags (Environment, System, Owner) are required and propagated

### Conventions
- Modules are source-code free: they accept artefact references (S3 locations, image URIs, ARNs) and configuration — never bundle application code
- British English in documentation and comments (standardised, catalogue, artefact)
- Modules follow semantic versioning: breaking input/output changes = major, additive inputs/outputs = minor, internal fixes = patch; `CHANGELOG.md` is curated by humans before each release tag

### CI Pipeline (`.github/workflows/ci.yml`)
Eight jobs run on every PR: `terraform fmt` → `terraform validate` → `terraform test` (matrix across all 15 modules) → `manifest schema` (subsystem.yaml files against `schema/subsystem.schema.json`) → `tflint` → `conftest` OPA → `trivy` → LocalStack smoke test. All must pass (see `.github/required-checks.md`).

### Manifest abstraction and delivery topology
The library is consumed, not deployed. The deployment topology lives outside it:
- **`modules/composition/subsystem`** renders a whole subsystem from a `subsystem.yaml` manifest (schema: `schema/subsystem.schema.json`).
- **`templates/subsystem-app/`** is the paved-road *app repo* template: a tiny Terraform root pinning the library + co-located Lambda services + a `manage-infra` workflow. App repos own state and apply; the library never does.
- **`.github/actions/terraform-deploy`** is the reusable OIDC plan/apply/destroy action the app repo's `manage-infra` calls behind a GitHub Environment approval gate.
- **`.github/workflows/author-subsystem.yml`** is the front door for self-service/agentic callers: given a manifest + target repo, it scaffolds a new app repo from the template (greenfield) or PRs the manifest into an existing one (brownfield). Writes cross-repo, so it needs the `SUBSYSTEM_AUTHOR_TOKEN` secret (App/PAT with repo admin on the target org). Nothing is applied — a human reviews and the app repo deploys.
- **`.github/actions/validate-manifest`** validates manifests against the schema (used by CI's `manifest schema` job and by `author-subsystem`).

See `docs/self-service-integration.md` for the full flow and `docs/architecture/deployment-flow.svg` for the diagram.
