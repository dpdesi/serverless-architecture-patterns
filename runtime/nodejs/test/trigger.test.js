import { test } from "node:test";
import assert from "node:assert/strict";
import { createTriggerHandler, parseStreamRecord } from "../src/trigger.js";
import { createEvent } from "../src/envelope.js";
import { NonRetryableError } from "../src/errors.js";

const streamRecord = (sequenceNumber, eventName, newImage, oldImage) => ({
  eventID: `evt-${sequenceNumber}`,
  eventName,
  dynamodb: {
    SequenceNumber: sequenceNumber,
    Keys: { pk: { S: "order-1" }, sk: { S: "Order" } },
    ...(newImage ? { NewImage: newImage } : {}),
    ...(oldImage ? { OldImage: oldImage } : {}),
  },
});

test("parseStreamRecord unmarshalls keys and images", () => {
  const change = parseStreamRecord(
    streamRecord("100", "INSERT", {
      pk: { S: "order-1" },
      total: { N: "8600" },
      paid: { BOOL: false },
      lines: { L: [{ M: { sku: { S: "A" }, qty: { N: "2" } } }] },
    }),
  );
  assert.equal(change.eventName, "INSERT");
  assert.deepEqual(change.keys, { pk: "order-1", sk: "Order" });
  assert.deepEqual(change.newImage, {
    pk: "order-1",
    total: 8600,
    paid: false,
    lines: [{ sku: "A", qty: 2 }],
  });
  assert.equal(change.sequenceNumber, "100");
});

test("published events flow from toEvents and failures key on SequenceNumber", async () => {
  const published = [];
  const handler = createTriggerHandler({
    toEvents: (change) => {
      if (change.eventName === "REMOVE") throw new Error("transient");
      return createEvent({
        type: "OrderPlaced",
        partitionKey: change.keys.pk,
        timestamp: 1,
        data: change.newImage,
      });
    },
    publish: async (events) => published.push(...events),
  });
  const result = await handler({
    Records: [
      streamRecord("100", "INSERT", { pk: { S: "order-1" } }),
      streamRecord("101", "REMOVE"),
    ],
  });
  assert.equal(published.length, 1);
  assert.equal(published[0].type, "OrderPlaced");
  assert.deepEqual(result.batchItemFailures, [{ itemIdentifier: "101" }]);
});

test("toEvents may return nothing to skip a change", async () => {
  const published = [];
  const handler = createTriggerHandler({
    toEvents: () => undefined,
    publish: async (events) => published.push(...events),
  });
  const result = await handler({ Records: [streamRecord("100", "MODIFY", {})] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(published.length, 0);
});

test("toEvents may return an array of envelopes", async () => {
  const published = [];
  const handler = createTriggerHandler({
    toEvents: () => [
      createEvent({ type: "A", partitionKey: "1", timestamp: 1 }),
      createEvent({ type: "B", partitionKey: "1", timestamp: 1 }),
    ],
    publish: async (events) => published.push(...events),
  });
  await handler({ Records: [streamRecord("100", "INSERT", {})] });
  assert.deepEqual(
    published.map((envelope) => envelope.type),
    ["A", "B"],
  );
});

test("non-retryable mapping failures fault and skip", async () => {
  const published = [];
  const handler = createTriggerHandler({
    toEvents: () => {
      throw new NonRetryableError("unmappable row");
    },
    publish: async (events) => published.push(...events),
  });
  const result = await handler({ Records: [streamRecord("100", "INSERT", {})] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(published.length, 1);
  assert.equal(published[0].type, "fault");
  assert.equal(published[0].uow.sequenceNumber, "100");
});

test("toEvents is required", () => {
  assert.throws(() => createTriggerHandler({}), /toEvents function is required/);
});
