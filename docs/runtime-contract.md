# The service runtime contract

The Terraform modules in this library wire infrastructure around a set of assumptions about what
the Lambda code inside each component does: how events are shaped, how failures are reported, and
how state changes become facts on the hub. This page makes those assumptions explicit. It is the
**normative contract** — any handler, in any language, that satisfies it will work with the
infrastructure the modules deploy.

A reference implementation for Node.js lives in [`runtime/nodejs`](../runtime/nodejs), and a
worked service built on it lives in [`examples/services/hello-service`](../examples/services/hello-service).

## Why a contract

The modules inject environment variables (`EVENT_BUS_NAME`, `TABLE_NAME`, `SERVICE_NAME`,
`COMPONENT`), configure `ReportBatchItemFailures` on every event source mapping, route
`detail-type: "fault"` events into the fault monitor, and give every queue a DLQ with a redrive
policy. None of that helps unless the code inside the function plays its part: publishing
well-formed envelopes, reporting partial batch failures correctly, and emitting fault events for
poison messages instead of retrying them forever. This contract is that part.

## The event envelope

Every fact a service publishes is an EventBridge event with this mapping:

| EventBridge field | Value |
| --- | --- |
| `Source` | `<subsystem>.<service>` — e.g. `order.checkout`. Taken from the `EVENT_SOURCE` env var when set, else `SERVICE_NAME`. |
| `DetailType` | The event type in PascalCase — e.g. `OrderPlaced`, `PaymentCaptured`. Or the literal `fault`. |
| `Detail` | The envelope, JSON-encoded. |

The envelope inside `Detail`:

```json
{
  "id": "3f2a9c1e-4b7d-0e8f-a1b2-c3d4e5f60718",
  "type": "OrderPlaced",
  "timestamp": 1719878400000,
  "partitionKey": "order-51349",
  "tags": {
    "service": "checkout",
    "component": "trigger"
  },
  "data": {
    "orderId": "51349",
    "total": 8600
  }
}
```

| Field | Rules |
| --- | --- |
| `id` | Unique per fact. **Deterministic** — derived from `type + partitionKey + timestamp` (see Idempotency below), so a replayed or duplicated publish produces the same id. |
| `type` | Same value as `DetailType`. Consumers switch on this. |
| `timestamp` | Epoch milliseconds when the fact occurred (not when it was published). |
| `partitionKey` | The domain identity the fact is about (order id, customer id). Consumers use it for sharding and for idempotency keys. |
| `tags` | Provenance: at minimum `service` and `component`. Free to extend (e.g. `region` for multi-region replication loop prevention). |
| `data` | The fact payload — event-carried state, enough for a consumer to act without calling back. |

## Idempotency and order tolerance

The hub guarantees **at-least-once** delivery, and replay (from the event lake or the fault
monitor) deliberately re-delivers. Consumers must therefore be:

- **Idempotent** — processing the same event twice must produce the same result as once. The
  deterministic `id` is the tool: use it (or `partitionKey` + `type` + `timestamp`) as the
  condition in a conditional write, so a duplicate becomes a no-op instead of a double-apply.
- **Order-tolerant** — events may arrive out of order across partition keys (and after a replay,
  within one). Use *inverse optimistic locking*: only apply an event if its `timestamp` is newer
  than the timestamp already stored on the row it updates.

## Components and their obligations

### `rest` (BFF synchronous path)

- Receives API Gateway v2 (HTTP API) proxy events; returns `{ statusCode, headers, body }`.
- Owns the service's table: reads and writes go here, **database-first** — the handler writes
  state and returns; it does not publish events itself. The `trigger` turns the write into a fact.
- May publish *task* events directly for actions that don't change owned state.

### `listener` (inbound events → owned view)

- Event source: SQS (the hub delivers matched events into the service's listener queue).
  Each SQS `record.body` is a **full EventBridge event** — parse it and read `detail` for the
  envelope, `detail-type` for the type.
- Must return `{ "batchItemFailures": [{ "itemIdentifier": "<messageId>" }, ...] }` listing only
  the records that failed **retryably**. Everything else is deleted from the queue.
- **Retryable failure** (dependency down, throttle): report the item; SQS redelivers, and after
  `maxReceiveCount` the redrive policy moves it to the DLQ.
- **Non-retryable failure** (malformed payload, business-rule violation — retrying cannot help):
  publish a **fault event** (below) and *do not* report the item. The poison message leaves the
  queue; the fault monitor preserves it for diagnosis and resubmission.

### `trigger` (owned table → outbound facts)

- Event source: the owned table's DynamoDB stream. Must return batch item failures keyed by the
  record's **`dynamodb.SequenceNumber`** (not messageId).
- Maps each change record (`INSERT` / `MODIFY` / `REMOVE`, with unmarshalled `NewImage` /
  `OldImage`) to zero or more envelopes and publishes them to `EVENT_BUS_NAME`.
- Same retryable / non-retryable split as the listener. A failed batch item is retried by the
  stream up to the module's `maximum_retry_attempts`, then delivered to the trigger's on-failure
  SQS destination.
- Suppress echo loops: if the listener writes materialised rows into the same table, the trigger
  must recognise and skip them (e.g. by an attribute the listener stamps), or publish them under a
  type nothing in this subsystem subscribes to.

### `ingress` / `egress` (ESG)

- `ingress`: receives external input (webhook via the HTTP API, or a poll), **normalises** it into
  the subsystem's envelope vocabulary, publishes to the hub. External identifiers go in `data`;
  never let the external system's schema leak into event types.
- `egress`: SQS-fed like a listener (the egress queue), delivers events to the external system's
  API. Same failure semantics; credentials come from the Secrets Manager / SSM ARNs granted by the
  module, never from environment variables.

## Fault events

A fault event is how a component sets aside work it cannot do, without losing it:

```json
{
  "id": "…",
  "type": "fault",
  "timestamp": 1719878400000,
  "partitionKey": "order-51349",
  "tags": { "service": "checkout", "component": "listener", "functionName": "order-checkout-listener" },
  "err": { "name": "ValidationError", "message": "quantity must be positive", "stack": "…(truncated)…" },
  "uow": { "…the original record/event being processed…": "…" }
}
```

- `DetailType` is the literal string `fault` — this is what the fault monitor's rule matches.
- `uow` (unit of work) carries the **original input** so an operator (or the resubmission CLI) can
  re-invoke the owning function with it once the cause is fixed.
- `err.stack` should be truncated (the runtime caps it at 4 KB) — EventBridge entries are limited
  to 256 KB total.
- If publishing the fault event itself fails, the component must fall back to reporting the item
  as a batch failure so nothing is silently dropped.

## Environment variables the modules inject

| Variable | Injected into | Meaning |
| --- | --- | --- |
| `EVENT_BUS_NAME` | all components | The subsystem hub. Publish here. |
| `SERVICE_NAME` | all components | The service's deployed name; default event `Source` and `tags.service`. |
| `COMPONENT` | all components | `rest` / `listener` / `trigger` / `ingress` / `egress`; default `tags.component`. |
| `TABLE_NAME` | BFF components, control reactor | The owned DynamoDB table. |
| `EVENT_SOURCE` | *optional, caller-set* | Overrides the publish `Source` when it should differ from `SERVICE_NAME`. |

## The reference implementation

[`runtime/nodejs`](../runtime/nodejs) implements this contract as a zero-dependency ES-module
package (the AWS SDK v3 it needs at runtime is provided by the Lambda Node.js runtime):

```js
import { createListenerHandler, NonRetryableError } from "@atrium/service-runtime";

export const handler = createListenerHandler({
  async onEvent(event) {
    if (!event.detail?.data?.orderId) {
      throw new NonRetryableError("event has no orderId");   // → fault event, not retried
    }
    await materialise(event.detail);                          // throws → retried via SQS
  },
});
```

`createTriggerHandler`, `createRestHandler`, `createEvent`, `createFaultEvent`, and
`publishEvents` cover the rest of the contract. See the package README for the full API and
[`examples/services/hello-service`](../examples/services/hello-service) for a complete service.

### Using it from an app repo

The package is not published to a public registry. Vendor it into your app repository (copy
`runtime/nodejs` to e.g. `vendor/service-runtime`) or publish it to your organisation's private
registry, then depend on it per component:

```json
{ "dependencies": { "@atrium/service-runtime": "file:../../../vendor/service-runtime" } }
```

The template's build step runs `npm ci` for any component with a `package.json`, so `file:`
dependencies are packed into the artefact automatically. The contract — not the package — is the
requirement; a Python or Go implementation that honours this page works identically.
