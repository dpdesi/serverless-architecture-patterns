# @atrium/service-runtime

The Node.js reference implementation of the [runtime contract](../../docs/runtime-contract.md):
event envelopes, hub publishing, and handler factories for the `listener`, `trigger`, and `rest`
components the pattern modules deploy.

Zero package dependencies. The AWS SDK v3 client it uses at runtime
(`@aws-sdk/client-eventbridge`) is provided by the Lambda Node.js runtime, and unit tests inject
fakes, so `node --test` runs offline with no install step.

## API

### Envelopes

```js
import { createEvent, createFaultEvent, deterministicId } from "@atrium/service-runtime";

const fact = createEvent({
  type: "OrderPlaced",          // becomes the EventBridge DetailType
  partitionKey: order.id,       // the domain identity the fact is about
  timestamp: order.placedAt,    // when it happened (defaults to now)
  data: { orderId: order.id, total: order.total },
});
// fact.id is deterministic: replaying the same publish yields the same id,
// so consumers can dedupe with a conditional write.
```

### Publishing

```js
import { publishEvents } from "@atrium/service-runtime";

await publishEvents([fact]);   // bus from EVENT_BUS_NAME, source from EVENT_SOURCE ?? SERVICE_NAME
```

Batches of more than ten are chunked (the PutEvents limit); any failed entry throws so the caller
retries the whole unit of work.

### Listener (hub events -> owned view)

```js
import { createListenerHandler, NonRetryableError } from "@atrium/service-runtime";

export const handler = createListenerHandler({
  async onEvent(event) {                   // { id, type, source, time, detail, raw }
    if (!event.detail?.data?.orderId) {
      throw new NonRetryableError("no orderId");  // -> fault event, record deleted
    }
    await materialise(event.detail);       // any other throw -> retried via SQS
  },
});
```

### Trigger (owned table stream -> facts)

```js
import { createTriggerHandler, createEvent } from "@atrium/service-runtime";

export const handler = createTriggerHandler({
  toEvents(change) {                       // { eventName, keys, newImage, oldImage, sequenceNumber }
    if (change.eventName !== "INSERT") return;   // return nothing to skip
    return createEvent({
      type: "ThingCreated",
      partitionKey: change.keys.pk,
      data: change.newImage,
    });
  },
});
```

### REST (HTTP API)

```js
import { createRestHandler, json } from "@atrium/service-runtime";

export const handler = createRestHandler({
  "GET /things/{id}": async ({ pathParameters }) => json(200, await get(pathParameters.id)),
  "POST /things":     async ({ body, claims }) => json(201, await put(body, claims.sub)),
});
```

## Failure semantics (the part that matters)

| Situation | What the factories do |
| --- | --- |
| Handler throws an ordinary `Error` | Record reported in `batchItemFailures` → redelivered; DLQ after `maxReceiveCount` / `maximum_retry_attempts`. |
| Handler throws `NonRetryableError` (or any error with `nonRetryable = true`) | A **fault event** is published carrying the original unit of work; the record is *not* reported, so it leaves the queue/stream. The fault monitor archives and alerts. |
| The fault publish itself fails | Fall back to `batchItemFailures` — nothing is ever silently dropped. |

## Using it from an app repo

This package is not on a public registry. Copy this directory into your app repository (e.g.
`vendor/service-runtime`) or publish it to your organisation's registry, then per component:

```json
{ "dependencies": { "@atrium/service-runtime": "file:../../../vendor/service-runtime" } }
```

The subsystem-app template's build step runs `npm ci` for any component with a `package.json`, so
the dependency is packed into the Lambda zip automatically.

## Tests

```bash
node --test
```
