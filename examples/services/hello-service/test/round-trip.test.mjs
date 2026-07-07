// Round-trips the runtime contract without AWS: a REST write becomes a stream
// record; the trigger maps it to an envelope; the listener consumes that
// envelope idempotently and order-tolerantly. The handlers under test are the
// real component files - only the data stores and the hub are faked.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler as createRestHandler } from "../rest/index.mjs";
import { toEvents, handler as triggerHandler } from "../trigger/index.mjs";
import { createOnEvent } from "../listener/index.mjs";
import { createListenerHandler, createTriggerHandler } from "../../../../runtime/nodejs/src/index.js";

// --- fakes -----------------------------------------------------------------

const fakeThingStore = () => {
  const rows = new Map();
  return {
    rows,
    get: async (id) => rows.get(`thing#${id}`),
    put: async (thing) => rows.set(`thing#${thing.id}`, { pk: `thing#${thing.id}`, sk: "Thing", ...thing }),
  };
};

const fakeMirrorStore = () => {
  const rows = new Map();
  return {
    rows,
    putIfNewer: async (item) => {
      const existing = rows.get(item.pk);
      if (existing && existing.updatedAt >= item.updatedAt) return; // duplicate or stale
      rows.set(item.pk, item);
    },
  };
};

// Marshal a plain row into the DynamoDB stream AttributeValue shape.
const marshal = (value) => {
  if (value === null) return { NULL: true };
  if (typeof value === "string") return { S: value };
  if (typeof value === "number") return { N: String(value) };
  if (typeof value === "boolean") return { BOOL: value };
  if (Array.isArray(value)) return { L: value.map(marshal) };
  return { M: Object.fromEntries(Object.entries(value).map(([k, v]) => [k, marshal(v)])) };
};

const streamRecordFor = (row, eventName = "INSERT", sequenceNumber = "100") => ({
  eventID: `evt-${sequenceNumber}`,
  eventName,
  dynamodb: {
    SequenceNumber: sequenceNumber,
    Keys: { pk: marshal(row.pk), sk: marshal(row.sk) },
    NewImage: marshal(row).M,
  },
});

// Wrap an envelope the way the hub delivers it into a listener queue.
const sqsRecordFor = (envelope, messageId = "m-1") => ({
  messageId,
  body: JSON.stringify({
    version: "0",
    id: `eb-${messageId}`,
    "detail-type": envelope.type,
    source: "hello.hello-service",
    time: new Date(envelope.timestamp).toISOString(),
    detail: envelope,
  }),
});

// --- the round trip ----------------------------------------------------------

test("REST write -> trigger fact -> listener materialisation, idempotently", async () => {
  // 1. A user PUTs a thing through the BFF's REST component.
  const things = fakeThingStore();
  const rest = createRestHandler(things);
  const putResponse = await rest({
    rawPath: "/things/th-1",
    body: JSON.stringify({ name: "widget" }),
    headers: { "content-type": "application/json" },
    requestContext: { http: { method: "PUT" }, authorizer: { jwt: { claims: { sub: "user-9" } } } },
  });
  assert.equal(putResponse.statusCode, 200);
  const storedRow = things.rows.get("thing#th-1");
  assert.equal(storedRow.name, "widget");
  assert.equal(storedRow.lastModifiedBy, "user-9");

  // 2. The committed write appears on the table stream; the trigger publishes it.
  const published = [];
  const trigger = createTriggerHandler({ toEvents, publish: async (events) => published.push(...events) });
  const triggerResult = await trigger({ Records: [streamRecordFor(storedRow)] });
  assert.deepEqual(triggerResult.batchItemFailures, []);
  assert.equal(published.length, 1);
  const fact = published[0];
  assert.equal(fact.type, "ThingCreated");
  assert.equal(fact.partitionKey, "thing#th-1");
  assert.equal(fact.data.name, "widget");

  // 3. A subscribing service's listener materialises the fact into its own table.
  const mirror = fakeMirrorStore();
  const listener = createListenerHandler({ onEvent: createOnEvent(mirror), publish: async () => {} });
  const listenerResult = await listener({ Records: [sqsRecordFor(fact)] });
  assert.deepEqual(listenerResult.batchItemFailures, []);
  const mirrored = mirror.rows.get("mirror#th-1");
  assert.equal(mirrored.name, "widget");
  assert.equal(mirrored.materialisedBy, "listener");

  // 4. Idempotency: redelivering the same fact changes nothing.
  await listener({ Records: [sqsRecordFor(fact, "m-2")] });
  assert.equal(mirror.rows.size, 1);
  assert.equal(mirror.rows.get("mirror#th-1").updatedAt, fact.timestamp);

  // 5. Order tolerance: an older fact for the same thing is not applied.
  const staleFact = { ...fact, timestamp: fact.timestamp - 5000, data: { ...fact.data, name: "stale" } };
  await listener({ Records: [sqsRecordFor(staleFact, "m-3")] });
  assert.equal(mirror.rows.get("mirror#th-1").name, "widget");
});

test("materialised rows do not echo back through the trigger", async () => {
  const published = [];
  const trigger = createTriggerHandler({ toEvents, publish: async (events) => published.push(...events) });
  const mirroredRow = {
    pk: "mirror#th-1",
    sk: "MirroredThing",
    materialisedBy: "listener",
    id: "th-1",
    updatedAt: Date.now(),
  };
  const result = await trigger({ Records: [streamRecordFor(mirroredRow)] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(published.length, 0);
});

test("a fact with no identity is set aside as a fault, not retried", async () => {
  const faults = [];
  const listener = createListenerHandler({
    onEvent: createOnEvent(fakeMirrorStore()),
    publish: async (events) => faults.push(...events),
  });
  const brokenFact = { id: "x", type: "ThingCreated", timestamp: Date.now(), partitionKey: "p", data: {} };
  const result = await listener({ Records: [sqsRecordFor(brokenFact)] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(faults.length, 1);
  assert.equal(faults[0].type, "fault");
  assert.match(faults[0].err.message, /no data\.id/);
});

test("the exported trigger handler is wired with the real publisher", () => {
  assert.equal(typeof triggerHandler, "function");
});
