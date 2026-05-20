# Developer Guide

## Onboarding

Install Terraform, Docker, TFLint, Conftest, and Trivy. Terraform and Docker are enough for early authoring; CI runs the full gate set.

Clone the repository and run:

```sh
terraform fmt -check -recursive
./scripts/validate.sh
```

## Local Validation

The validation script initialises every example and reference stack with `-backend=false`, then runs `terraform validate`.

Run module contract tests individually:

```sh
terraform test modules/primitives/eventbridge_bus
terraform test modules/patterns/event_hub
terraform test modules/patterns/esg_service
terraform test modules/patterns/control_service
terraform test modules/patterns/event_lake
```

Run policies:

```sh
conftest test tests/fixtures/pass --policy policies/opa
! conftest test tests/fixtures/fail --policy policies/opa
```

## Running The Customer Subsystem Smoke Path

```sh
docker compose up -d localstack
cd examples/subsystem-core/customer-subsystem
terraform init
terraform apply -auto-approve
terraform output
```

If LocalStack coverage is insufficient for a resource in your edition, use a short-lived AWS dev account and replace the LocalStack provider endpoints with normal AWS provider configuration.

## Planning And Deploying To Dev

Use remote state and provider aliases in `stacks/envs/dev` once your organisation has chosen its backend. Keep environment-specific values outside modules and pass them through root stacks.

Minimum PR evidence:

- Format, validate, lint, test, policy, and scan checks pass.
- Example plans are attached or linked.
- Security exceptions are explicit and time-bound.
