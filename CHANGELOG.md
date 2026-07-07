# Changelog

All notable changes to this repository are documented here.

## 0.2.0 - 2026-07-07

First published release. Everything below shipped together as the initial tag;
the `subsystem-app` template and the `terraform-deploy` action pin against it.

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
- (additive) ADOT instrumentation is now wired, not just declared: the `lambda_function` primitive
  gains a `layers` input, every pattern that builds functions (`bff_service`, `control_service`,
  `esg_service`, `micro_frontend`) forwards it, and the composer attaches the AWS Distro for
  OpenTelemetry layer plus the OpenTelemetry exec wrapper to every function when
  `operations.observability.adot_layer_arn` is set (off by default: functions otherwise keep X-Ray
  active tracing). Removed the `OPENTELEMETRY_COLLECTOR_CONFIG_FILE = /opt/otel/config.yaml` env var
  that pointed at a config file nothing shipped (it would have broken the collector); the
  `public_app` and `customer-engagement-system` reference stacks no longer set the exec wrapper
  without a layer.
- (fix) `fault_monitor` SNS topic policy now also grants its own CloudWatch alarms `sns:Publish`
  (the replacement topic policy previously locked them out); `bff_service`/`control_service`/`esg_service`
  no longer create a redundant per-Lambda async DLQ on their SQS-invoked functions (it collided in
  name with the pattern-level DLQ).
- Add the runtime contract (`docs/runtime-contract.md`): the normative spec for what the Lambda
  code inside each component must do — the event envelope and its EventBridge mapping,
  deterministic ids, idempotency and order-tolerance duties, per-component obligations, fault
  events, and the environment variables the modules inject. Ships with a zero-dependency Node.js
  reference implementation (`runtime/nodejs`, 34 unit tests via `node --test`, no install step)
  and a complete worked service (`examples/services/hello-service`) whose round-trip test walks a
  REST write through the stream trigger onto the hub and into a subscribing listener. New
  `runtime-tests` CI job and `make runtime-test` target.
- Add the `identity` pattern (`modules/patterns/identity`): a Cognito user pool with the library's
  security posture as defaults (deletion protection, 12-character complex passwords, software-token
  MFA available, self sign-up off), a `clients` map (public SPA clients without secrets;
  confidential clients with), and an optional hosted UI domain. Its `jwt_authorizer` output is
  shaped exactly for the `bff_service` / `esg_service` / `api_http` input of the same name.
- Add the `artefact_pipeline` module under a new `modules/delivery/` category: the versioned,
  KMS-encrypted, TLS-only artefact bucket the whole library assumes, plus an optional GitHub-OIDC
  publisher role scoped to one repository. The `subsystem-app` template gains
  `scripts/preflight.sh`, wired into `manage-infra`, verifying the bucket before every plan and
  every expected artefact (co-located and external) after the build — failing with instructions
  instead of an opaque apply error.
- Add **Identity** and **Artefact Pipeline** tabs to `patterns-clean.drawio` (19 pages), exported
  and embedded in the pattern reference.
