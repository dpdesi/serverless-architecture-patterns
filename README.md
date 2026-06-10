# Serverless Architecture Patterns

Production-oriented Terraform for building **autonomous, event-driven serverless subsystems on AWS** — a pattern catalogue that implements the architecture in *Software Architecture Patterns for Serverless Systems* (Packt).

## What this repo is

It is a library you build *with*, organised in three layers, each usable on its own:

1. **Primitives** (`modules/primitives/`) — single AWS resources hardened with the library's security defaults (customer-managed KMS everywhere, finite log retention, dedicated least-privilege roles, DLQs on every async path, required tags).
2. **Patterns** (`modules/patterns/`) — the named building blocks from the book: the **event hub** that every service collaborates through, **BFF** services for user activities, **control** services (event reactors and Step Functions sagas), **ESG** gateways that isolate external systems, plus the operational set (event lake, fault monitor, observability baseline, regional health check, frontend edge, micro-frontend).
3. **Composition** (`modules/composition/subsystem`) — the abstraction on top: describe a whole subsystem in one declarative `subsystem.yaml` manifest and the composer instantiates and *wires* the patterns together (hub routes, the queue policies EventBridge needs, DLQs, glue IAM, KMS service grants, observability inputs).

The shared idea throughout: **services never call each other** — they exchange events through the hub, each owns its own data, and the resulting bulkheads keep one service's failure from cascading. Producers publish facts; consumers cache what they need. This is what makes the subsystems *autonomous*.

The architecture is documented visually in [docs/architecture/patterns-clean.drawio](docs/architecture/patterns-clean.drawio) — a **Pattern Icons** key (each pattern as one glyph), one detail tab per pattern, and two worked application examples (an online-order system and a payments payout process) drawn from those glyphs.

Ways to use it: compose the pattern modules directly, write a manifest and let the composer wire it, start from a worked example, scaffold a new repo from the Backstage/CLI templates, or open a PR from a manifest through the `subsystem-pr` GitHub workflow.

## Architecture Overview

The Phase 1 implementation covers:

| Pattern | Status | Terraform entry point |
| --- | --- | --- |
| Lambda function primitive | Implemented | `modules/primitives/lambda_function` |
| HTTP API primitive | Implemented | `modules/primitives/api_http` |
| DynamoDB table primitive | Implemented | `modules/primitives/dynamodb_table` |
| EventBridge bus primitive | Implemented | `modules/primitives/eventbridge_bus` |
| Event hub | Implemented | `modules/patterns/event_hub` |
| BFF service | Implemented | `modules/patterns/bff_service` |
| Observability baseline | Implemented | `modules/patterns/observability_baseline` |
| ESG service | Implemented | `modules/patterns/esg_service` |
| Control Service | Implemented | `modules/patterns/control_service` |
| Event lake | Implemented | `modules/patterns/event_lake` |
| Frontend edge | Implemented | `modules/patterns/frontend_edge` |
| Regional health check | Implemented | `modules/patterns/regional_health_check` |
| Fault monitor | Implemented | `modules/patterns/fault_monitor` |
| Micro-frontend manifest deployer | Implemented | `modules/patterns/micro_frontend` |
| Subsystem core | Implemented | `stacks/reference/subsystem_core` |
| Public app | Implemented | `stacks/reference/public_app` |
| Subsystem composition (manifest) | Implemented | `modules/composition/subsystem` |

For a worked end-to-end domain example showing how the building blocks compose, see the **Online order subsystem** tab in [docs/architecture/patterns-clean.drawio](docs/architecture/patterns-clean.drawio) — it labels every component with both its business name (Catalogue BFF, Inventory Allocator, Payments Gateway, etc.) and the bracketed module it is built from (`[bff_service]`, `[control_service] - event_reactor`, `[esg_service]`, ...).

## Composing a subsystem from a manifest

Instead of hand-wiring the pattern modules, describe the subsystem in a single `subsystem.yaml` (schema: [schema/subsystem.schema.json](schema/subsystem.schema.json), vocabulary matching the pattern glyphs in the architecture diagram) and let `modules/composition/subsystem` derive the wiring — hub routes, queue policies, DLQs, glue IAM, KMS service grants and observability inputs:

```hcl
module "payouts" {
  source   = "../../modules/composition/subsystem"
  manifest = yamldecode(file("${path.module}/subsystem.yaml"))
}
```

See [examples/systems/payouts-subsystem](examples/systems/payouts-subsystem) for a complete worked example. The `subsystem-pr` GitHub workflow turns a pasted manifest into a reviewable PR (validate → render → `terraform validate` → PR); it is the intended target for self-service and agentic interfaces.

## Quickstart

```sh
cd serverless-architecture-patterns
terraform fmt -check -recursive
./scripts/validate.sh
```

On Windows PowerShell:

```powershell
cd serverless-architecture-patterns
terraform fmt -check -recursive
.\scripts\validate.ps1
```

For the LocalStack smoke path:

```sh
docker compose up -d localstack
cd examples/subsystem-core/customer-subsystem
terraform init
terraform apply -auto-approve
terraform output
```

For a complete system composition:

```sh
cd examples/systems/customer-engagement-system
terraform init -backend=false
terraform validate
```

The complete system example wires the event hub, BFF, Control Service, ESG, event lake, and observability baseline together around a customer engagement subsystem. To plan or apply it, copy `terraform.tfvars.example`, replace the placeholder application artefact references with real CI/CD-published S3 locations, and run `terraform plan -var-file=dev.tfvars`.

## Repository Layout

```text
modules/      Reusable primitives and pattern modules
stacks/       Reference compositions and environment roots
templates/    Backstage and CLI scaffolds
examples/     Runnable examples and the LocalStack smoke path
policies/     OPA and Sentinel policy packs
tests/        Fixtures, smoke tests, and integration helpers
docs/         Architecture, ADRs, and contributor guides
```

## Local Validation

Use the same gates as CI:

```sh
terraform fmt -check -recursive
tflint --init && tflint --recursive
terraform test modules/primitives/eventbridge_bus
conftest test tests/fixtures/pass --policy policies/opa
trivy config .
```

Some tools may not be installed locally. CI installs Terraform, TFLint, Conftest, and Trivy before running the full gate set.

## Release And Versioning

Modules follow semantic versioning. Breaking input/output changes require a major version, additive inputs and outputs require a minor version, and internal fixes require a patch version. `CHANGELOG.md` is curated by humans before each release tag.
