# Serverless Architecture Patterns

Production-oriented Terraform implementations of serverless architecture patterns for autonomous subsystems on AWS.

This repository provides reusable Terraform modules, reference stacks, scaffolds, tests, diagrams, and policy gates for building autonomous serverless subsystems on AWS. It is intended to be useful as a standalone infrastructure pattern catalogue: teams can compose the modules directly, start from the examples, or generate new subsystem repositories from the scaffolds.

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

For a worked end-to-end domain example showing how the building blocks compose, see the **Online order subsystem** tab in [docs/architecture/patterns-clean.drawio](docs/architecture/patterns-clean.drawio) — it labels every component with both its business name (Catalogue BFF, Inventory Allocator, Payments Gateway, etc.) and the bracketed module it is built from (`[bff_service]`, `[control_service] - event_reactor`, `[esg_service]`, ...).

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
