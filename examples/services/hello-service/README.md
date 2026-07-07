# hello-service

A complete BFF service written against the [runtime contract](../../../docs/runtime-contract.md)
using the [`@atrium/service-runtime`](../../../runtime/nodejs) reference implementation. It is the
code half of the `bff_service` pattern: the module deploys the infrastructure, and these three
handlers are what run inside it.

The imports use relative paths into `runtime/nodejs` because this example lives in the library
repository. In your own app repo, vendor the runtime and use a `file:` dependency instead — see
the runtime README.

## The three components

- [`rest/index.mjs`](rest/index.mjs) — synchronous HTTP handlers behind the BFF's API. Writes go
  **database-first**: the handler stores a `thing` row and returns; it does not publish events.
- [`trigger/index.mjs`](trigger/index.mjs) — consumes the table's stream and turns each committed
  write into a `ThingCreated` / `ThingUpdated` / `ThingDeleted` fact on the hub. Rows stamped by
  the listener are skipped so materialised views do not echo back as new facts.
- [`listener/index.mjs`](listener/index.mjs) — consumes hub events this service subscribes to and
  materialises them into the owned table, idempotently (conditional write on the event timestamp).

## What the tests demonstrate

`node --test examples/services/hello-service/test/` (from the repo root) round-trips the contract
without AWS: a REST write becomes a stream record, the trigger maps it to an envelope, the
listener consumes that envelope and applies it order-tolerantly. The DynamoDB client is faked; the
handlers under test are the exact files above.
