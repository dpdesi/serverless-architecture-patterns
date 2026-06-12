# Changelog

All notable changes to this repository are documented here.

## 0.1.0 - Unreleased

- Add Phase 1 primitives for Lambda, HTTP API, DynamoDB, and EventBridge.
- Add `event_hub` and `bff_service` pattern modules.
- Add subsystem core reference stack and customer subsystem LocalStack example.
- Add Backstage and CLI scaffold foundations.
- Add CI, policy, and security scan gates.
- Add Phase 2 ESG, Control Service, event lake, and observability baseline modules.
- Add Phase 2 examples and reference stacks for integration and records analytics.
- Add the `subsystem` composition module (`modules/composition/subsystem`): renders a whole
  autonomous subsystem from a declarative `subsystem.yaml` manifest (schema in
  `schema/subsystem.schema.json`), deriving hub routes, the SQS queue policies EventBridge
  needs to deliver into BFF listener queues, per-route DLQs, the events-to-Firehose glue role,
  the subsystem KMS key with its CloudWatch Logs / SNS / EventBridge service grants, and the
  observability inputs (functions + off-Lambda DLQ depth alarms). Worked example:
  `examples/systems/payouts-subsystem`.
- (additive) `event_hub` route targets gain `create_dead_letter_queue` (default true); `bff_service`
  gains `listener_queue_url`/`listener_queue_name`/`timeout_seconds` outputs; `control_service` and
  `esg_service` gain `timeout_seconds` outputs; `control_service` gains an `alarm_actions` input and
  `ExecutionsFailed`/`ExecutionsTimedOut` alarms in step_functions mode; `observability_baseline`
  gains a `monitored_queues` input for off-Lambda DLQ depth alarms; six pattern modules gain a
  `create_kms_key` flag (default true) so a parent composition can supply one shared key.
- Add the deployment topology around the manifest abstraction: the `subsystem-app` paved-road
  template (`templates/subsystem-app` — a tiny Terraform root pinning the library + co-located
  Lambda services + a gated `manage-infra` workflow), a reusable `terraform-deploy` composite
  action (OIDC plan/apply/destroy), a reusable `validate-manifest` action + `manifest schema` CI
  job, and the `author-subsystem` workflow_dispatch front door (scaffolds a new app repo from the
  template or PRs the manifest into an existing one). The library is consumed as a pinned
  dependency; app repos own state and apply.
- (additive) ingress-only ESGs: `esg_service.external_event_pattern` is now nullable (null skips the
  entire egress path - queue, handler, rule, DLQs - and requires the webhook API instead), the
  manifest schema makes `esgs[*].egress` optional when `webhook: true`, and the composer wires the
  conditional artefacts/observability accordingly. Models gateways that only receive provider
  callbacks (e.g. payment status webhooks) without a fake egress event.
- (fix) `fault_monitor` SNS topic policy now also grants its own CloudWatch alarms `sns:Publish`
  (the replacement topic policy previously locked them out); `bff_service`/`control_service`/`esg_service`
  no longer create a redundant per-Lambda async DLQ on their SQS-invoked functions (it collided in
  name with the pattern-level DLQ).
