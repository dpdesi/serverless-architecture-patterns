# Payouts subsystem (manifest-composed)

The payouts worked example from `docs/architecture/patterns-clean.drawio` ("Example: Payments Payout Process"), built from a single `subsystem.yaml` manifest by `modules/composition/subsystem`.

The manifest declares:

- **Initiation BFF** (task) and a read-only **Tracking BFF** (dashboard, CQRS view materialised from hub events)
- **Compliance Screening** (`control_service`, event-reactor) reacting to `PayoutRequested`
- **Execution Saga** (`control_service`, Step Functions) reacting to `PayoutApproved` and settlement events
- **Banking Rails Gateway** (`esg_service`) with an inbound webhook, matching `TransferInstructed` on egress
- The standard operations set: event lake (Object-Locked audit trail), fault monitor, observability baseline

Everything else - hub routes, SQS queue policies, the EventBridge-to-Firehose role, per-route DLQs, KMS service grants, observability inputs - is derived by the composition.

## Validate

```sh
terraform init -backend=false
terraform validate
```

## Deploy

1. Replace `artefact_defaults.bucket` in `subsystem.yaml` with the S3 bucket your CI/CD publishes Lambda artefacts to. Expected keys (or override per component): `lambda/payouts-<service>-<component>.zip`.
2. Replace the notification email placeholders.
3. Supply a real Amazon States Language definition for the execution saga (`state_machine_definition`) - the module's built-in placeholder accepts events and does nothing.
4. `terraform plan -var region=eu-west-2`

## Edge

The ops portal (CloudFront + manifest deployer) lives in us-east-1 and is composed separately - see "Edge composition" in `modules/composition/subsystem/README.md`. This root's `api_origins` output is ready to feed it.
