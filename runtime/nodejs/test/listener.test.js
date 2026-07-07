import { test } from "node:test";
import assert from "node:assert/strict";
import { createListenerHandler, parseHubRecord } from "../src/listener.js";
import { NonRetryableError } from "../src/errors.js";

const hubRecord = (messageId, detailType, detail) => ({
  messageId,
  body: JSON.stringify({
    version: "0",
    id: `eb-${messageId}`,
    "detail-type": detailType,
    source: "order.checkout",
    time: "2026-07-01T00:00:00Z",
    detail,
  }),
});

test("parseHubRecord exposes type, source and detail", () => {
  const parsed = parseHubRecord(hubRecord("m-1", "OrderPlaced", { data: { orderId: "1" } }));
  assert.equal(parsed.type, "OrderPlaced");
  assert.equal(parsed.source, "order.checkout");
  assert.deepEqual(parsed.detail, { data: { orderId: "1" } });
  assert.equal(parsed.raw["detail-type"], "OrderPlaced");
});

test("successful records are not reported as failures", async () => {
  const seen = [];
  const handler = createListenerHandler({
    onEvent: async (event) => seen.push(event.type),
    publish: async () => {},
  });
  const result = await handler({
    Records: [hubRecord("m-1", "A", {}), hubRecord("m-2", "B", {})],
  });
  assert.deepEqual(result, { batchItemFailures: [] });
  assert.deepEqual(seen, ["A", "B"]);
});

test("retryable failures are reported per record", async () => {
  const handler = createListenerHandler({
    onEvent: async (event) => {
      if (event.type === "Bad") throw new Error("dependency down");
    },
    publish: async () => {},
  });
  const result = await handler({
    Records: [hubRecord("m-1", "Good", {}), hubRecord("m-2", "Bad", {}), hubRecord("m-3", "Good", {})],
  });
  assert.deepEqual(result.batchItemFailures, [{ itemIdentifier: "m-2" }]);
});

test("non-retryable failures publish a fault and let the record delete", async () => {
  const published = [];
  const handler = createListenerHandler({
    onEvent: async () => {
      throw new NonRetryableError("malformed payload");
    },
    publish: async (events) => published.push(...events),
  });
  const result = await handler({ Records: [hubRecord("m-1", "X", {})] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(published.length, 1);
  assert.equal(published[0].type, "fault");
  assert.equal(published[0].err.message, "malformed payload");
  assert.equal(published[0].uow.messageId, "m-1");
});

test("a failed fault publish falls back to a batch failure", async () => {
  const handler = createListenerHandler({
    onEvent: async () => {
      throw new NonRetryableError("poison");
    },
    publish: async () => {
      throw new Error("EventBridge unavailable");
    },
  });
  const result = await handler({ Records: [hubRecord("m-1", "X", {})] });
  assert.deepEqual(result.batchItemFailures, [{ itemIdentifier: "m-1" }]);
});

test("duck-typed nonRetryable errors are honoured", async () => {
  const published = [];
  const handler = createListenerHandler({
    onEvent: async () => {
      const err = new Error("custom class");
      err.nonRetryable = true;
      throw err;
    },
    publish: async (events) => published.push(...events),
  });
  const result = await handler({ Records: [hubRecord("m-1", "X", {})] });
  assert.deepEqual(result.batchItemFailures, []);
  assert.equal(published[0].type, "fault");
});

test("onEvent is required", () => {
  assert.throws(() => createListenerHandler({}), /onEvent function is required/);
});
