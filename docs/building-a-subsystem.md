# Building a subsystem

The [pattern reference](patterns/README.md) covers the building blocks one at a time. This page is about the whole: how a single declarative manifest becomes a wired set of those patterns, the kind of system the worked examples describe.

You could instantiate the pattern modules yourself and connect them by hand. The composition layer ([`modules/composition/subsystem`](../modules/composition/subsystem)) does it for you from one file. It has two jobs: instantiate the patterns the manifest asks for, and derive the cross-pattern wiring that no single pattern can own. The second job is the interesting one, and most of this page is about it.

## The contract is the manifest

Everything starts from a `subsystem.yaml` manifest, validated against [`schema/subsystem.schema.json`](../schema/subsystem.schema.json). The composer takes exactly one input, the decoded manifest, and renders the whole subsystem from it:

```hcl
module "payouts" {
  source   = "../../../modules/composition/subsystem"
  manifest = yamldecode(file("${path.module}/subsystem.yaml"))
}
```

The manifest has these top-level keys. `subsystem` and `tags` are required; the rest are optional, and the operations block is on by default.

| Key | What it declares |
| --- | --- |
| `subsystem` | The name. Becomes the prefix on every resource. |
| `tags` | `Environment`, `System`, `Owner`, propagated everywhere. |
| `artefact_defaults` | The S3 bucket (and optional prefix) where Lambda zips live. |
| `hub` | Archive settings for the [event hub](patterns/event-hub.md). |
| `bffs` | The [BFF services](patterns/bff-service.md): one per user activity. |
| `controls` | The [control services](patterns/control-service.md): reactors and sagas. |
| `esgs` | The [ESG gateways](patterns/esg-service.md) to external systems. |
| `operations` | The [event lake](patterns/event-lake.md), [fault monitor](patterns/fault-monitor.md), [observability](patterns/observability-baseline.md), and [regional health](patterns/regional-health-check.md). |
| `edge` | The [frontend edge](patterns/frontend-edge.md) and [micro-frontend](patterns/micro-frontend.md). Read by a separate root, not the composer. |

## What the composer instantiates

Each part of the manifest maps to a pattern module:

| Manifest | Module | Created |
| --- | --- | --- |
| always | `event_hub` | exactly one |
| each `bffs[]` entry | `bff_service` | one per BFF |
| each `controls[]` entry | `control_service` | one per control (mode from the entry) |
| each `esgs[]` entry | `esg_service` | one per gateway |
| `operations.event_lake` | `event_lake` | when enabled (default) |
| `operations.fault_monitor` | `fault_monitor` | when enabled (default) |
| `operations.observability` | `observability_baseline` | when enabled (default) |
| `operations.regional_health` | `regional_health_check` | when enabled (off by default), requires a BFF |

Every one of these is passed `create_kms_key = false` and the subsystem's shared key, plus the Powertools and OpenTelemetry environment variables named after the service. That is the easy half. The patterns, on their own, do not know about each other. The wiring below is what makes them a subsystem rather than a pile of services.

## The wiring the composer derives

### The subsystem key and its service grants

The composer creates one customer-managed KMS key for the whole subsystem and hands it to every pattern, so all queues, tables, topics, buckets, and logs share one key with one rotation policy. A single key is only workable if its policy grants the AWS service principals that need to use it. The key policy grants, with conditions scoping each to this account:

- **EventBridge** decrypt and generate-data-key, so the bus can deliver into encrypted queues, plus an unconditional `DescribeKey` (required to attach the key to the bus) and a grant for EventBridge publishing into the encrypted SNS notification target.
- **CloudWatch** decrypt and generate-data-key, so alarms can use the key.
- **SNS** decrypt and generate-data-key, for the encrypted topics.
- **CloudWatch Logs** the encrypt and decrypt set, scoped by an encryption-context condition to this account's log groups.

Without these grants, a shared key would block the bus from delivering into queues and stop alarms from publishing. This is wiring that belongs to the composition, because only the composition knows the full set of services sharing the key.

### Hub routes

A pattern declares what it cares about; the composer turns that into hub routing. It builds one route per subscribing service:

- **Each BFF that `subscribes` to anything** gets a route keyed `<bff>-inbound`, with an event pattern matching that BFF's subscribed detail-types and a single target: the BFF's listener queue.
- **The event lake**, when enabled, gets a route keyed `event-lake` (see [below](#the-event-lake-route)).

A BFF with no subscriptions gets no route. In the payouts example, `initiation` only publishes, so it has no inbound route; `tracking` subscribes to five detail-types, so it has one. That is why the composer's `hub_route_keys` output for payouts is exactly `["event-lake", "tracking-inbound"]`. Control services and ESGs wire their own EventBridge rules inside their modules, so the composer does not build hub routes for them; it only routes into BFF listener queues and the lake.

### Per-route DLQs

Every route the composer creates gets its own dead-letter queue (`<hub>-<route>-dlq`), encrypted with the subsystem key, retaining failed deliveries for 14 days. Each DLQ has a policy allowing EventBridge to send to it, scoped to the exact rule ARN. These DLQs are built from a statically known set of route keys (not from module outputs), so Terraform can use them in a `for_each` without a dependency cycle.

### Listener queue policies

A [BFF](patterns/bff-service.md) creates its listener queue but deliberately does not allow EventBridge to deliver into it, because that policy must name a hub rule the BFF knows nothing about. The composer attaches it: for each subscribing BFF, an SQS policy granting `events:PutEvents` (`sqs:SendMessage`) to the EventBridge service principal, scoped to that BFF's inbound rule ARN.

To attach that policy without a dependency cycle (the hub needs the queue ARNs as targets, while the queue policy needs the rule ARN), the composer **predicts** the hub rule ARNs from the known naming convention rather than reading them back from the hub. Its `hub_rule_names` output exists so a contract test can check the prediction against the names the hub actually creates; if the hub ever renamed its rules, that test fails loudly instead of EventBridge silently failing to deliver.

### The event lake route

The [event lake](patterns/event-lake.md) module provisions only the sink (Firehose plus the locked bucket). The composer connects it to the hub:

- It creates an IAM role (`<subsystem>-events-to-firehose`) that EventBridge assumes to put records onto the Firehose stream (`firehose:PutRecord`, `firehose:PutRecordBatch`).
- It adds a hub route keyed `event-lake` whose target is the Firehose stream, using that role. The event pattern is the `detail_types` you listed, or a match-everything pattern when you listed none.

Disabling the lake (`operations.event_lake.enabled: false`) removes the route and the glue role as well as the bucket. The contract test `disabling_lake_removes_route_and_glue` checks exactly that.

### Monitoring coverage

The [observability baseline](patterns/observability-baseline.md) is only as good as the list of things it watches, and the composer builds that list so nothing is forgotten:

- **`lambda_functions`** is assembled from every function the composer created: each BFF's rest, listener, and trigger functions; each event-reactor control's listener and trigger functions; each ESG's ingress function, plus its egress function when it has an egress path. Step Functions sagas contribute no functions (they are watched by their own execution alarms instead).
- **`monitored_queues`** is assembled from the off-Lambda DLQs that would otherwise fail silently: every hub route DLQ, every control listener-rule DLQ, every saga workflow-rule DLQ, and every ESG egress-rule DLQ. In the payouts example this is five queues.

The result is that every function and every silent-failure queue in the subsystem has an alarm, derived automatically from what the manifest declared. The baseline's alarm topic ARN is also fed back into the event lake and fault monitor as their alarm action, so all alarms converge on one topic.

### Regional health alarms

When `operations.regional_health` is enabled, the composer builds the metric alarms the [health check](patterns/regional-health-check.md) aggregates: per BFF, a Lambda-errors alarm on the REST function and a system-errors alarm on the table. It uses the region from the manifest or the current region. Because the alarms are derived from BFFs, this operation requires at least one BFF.

## The edge exception

The [frontend edge](patterns/frontend-edge.md) and [micro-frontend](patterns/micro-frontend.md) are **not** provisioned by the composer. CloudFront and its ACM certificate are global resources that must be created with a `us-east-1` provider, and the composer runs in the subsystem's own region. So the manifest's `edge` block is read by a separate edge root instead. The [app template](../templates/subsystem-app) includes a dormant `us-east-1` edge module gated on `edge.enabled`, so a subsystem that needs a public frontend turns it on there while the composer handles everything regional.

## A worked example: payouts

[`examples/systems/payouts-subsystem`](../examples/systems/payouts-subsystem) is a complete, tested manifest for a payments payout subsystem. Its `subsystem.yaml` declares:

- **Two BFFs.** `initiation` (path `/payouts/*`) publishes `PayoutRequested`. `tracking` is read-only and subscribes to the five payout and transfer facts, building a status view from events.
- **Two controls.** `compliance-screening` is an event reactor that reacts to `PayoutRequested`. `execution-saga` is a Step Functions saga that runs the multi-step money movement on `PayoutApproved`.
- **One ESG.** `banking-rails` is a two-way gateway to the partner bank: it egresses `TransferInstructed` (the outbound transfer call) and exposes a webhook for the bank's callbacks.
- **Operations on.** Event lake, fault monitor, and observability enabled, with an on-call email; regional health off.

From those few dozen lines, the composer produces a couple of hundred AWS resources: the hub and its archive; three Lambdas, a table, two queues, and an API per BFF; the reactor's queues, table, and two Lambdas; the saga's state machine, roles, rule, and alarms; the gateway's ingress and egress paths; the locked event-lake bucket and its Firehose and route; the fault monitor's archive, topic, and rule; the full set of alarms and the dashboard; and the shared key, the route DLQs, the listener queue policy, and the glue role that connect them. Following the flow: a request to `initiation` publishes `PayoutRequested`; `compliance-screening` reacts; an approval flows to `tracking` (which updates its view) and to `execution-saga` (which orchestrates the transfer via `banking-rails`); every fact is archived in the lake; any fault is captured by the monitor; and every function and delivery DLQ is alarmed.

The same shape, in a different domain, is the **Online order** worked example on its own tab in [`patterns-clean.drawio`](architecture/patterns-clean.drawio): cart and tracking BFFs, a fulfilment saga, a shipping gateway, the same operations. It is the picture this whole library is for.

## Doing it by hand, and why you usually should not

[`examples/systems/customer-engagement-system`](../examples/systems/customer-engagement-system) wires the pattern modules directly, without the composer: it calls `event_hub`, `bff_service`, `control_service`, `esg_service`, `event_lake`, and `observability_baseline`, and writes the glue itself (the events-to-Firehose role, the hub's archive route, the explicit list of functions for observability). It is a useful reference for what the composer does under the hood, and the right approach if you need wiring the manifest schema does not express. For an ordinary subsystem it is more to write and more to get wrong: the manifest plus the composer is the paved road.

## What the composer rejects

Validation runs at plan time, before anything is created, so a malformed manifest fails fast:

- The subsystem name and every service name must match `^[a-z][a-z0-9-]{1,23}$`, and service names must be unique across BFFs, controls, and ESGs (they share the name prefix).
- Tags must include `Environment`, `System`, and `Owner`.
- Every control needs a valid mode and a non-empty `subscribes`. Every ESG needs either `egress` events or `webhook: true`.
- `regional_health` requires at least one BFF.
- Artefact sources must be resolvable: either `artefact_defaults.bucket`, or explicit artefacts for every component that needs code.

These checks are mirrored in the JSON Schema (so an editor and CI catch them too) and exercised by the composer's contract tests.

## Deploying it

The composer renders a subsystem; it does not deploy one. The library is consumed as a pinned dependency by an application repository that owns the Terraform state and runs the apply behind a human-approved gate. For that flow, see [Self-service and agentic integration](self-service-integration.md) and the [app template](../templates/subsystem-app).

---

[Back to the pattern reference](patterns/README.md)
