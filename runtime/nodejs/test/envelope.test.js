import { test } from "node:test";
import assert from "node:assert/strict";
import { createEvent, createFaultEvent, deterministicId } from "../src/envelope.js";

test("deterministicId is stable for the same inputs", () => {
  const a = deterministicId("OrderPlaced", "order-1", 1719878400000);
  const b = deterministicId("OrderPlaced", "order-1", 1719878400000);
  assert.equal(a, b);
  assert.match(a, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
});

test("deterministicId differs when any part differs", () => {
  const base = deterministicId("OrderPlaced", "order-1", 1);
  assert.notEqual(deterministicId("OrderPlaced", "order-2", 1), base);
  assert.notEqual(deterministicId("OrderCancelled", "order-1", 1), base);
  assert.notEqual(deterministicId("OrderPlaced", "order-1", 2), base);
});

test("createEvent builds a contract envelope with derived id and tags", () => {
  process.env.SERVICE_NAME = "checkout";
  process.env.COMPONENT = "trigger";
  const envelope = createEvent({
    type: "OrderPlaced",
    partitionKey: "order-1",
    timestamp: 1719878400000,
    data: { orderId: "1" },
  });
  assert.equal(envelope.type, "OrderPlaced");
  assert.equal(envelope.partitionKey, "order-1");
  assert.equal(envelope.timestamp, 1719878400000);
  assert.equal(envelope.id, deterministicId("OrderPlaced", "order-1", 1719878400000));
  assert.equal(envelope.tags.service, "checkout");
  assert.equal(envelope.tags.component, "trigger");
  assert.deepEqual(envelope.data, { orderId: "1" });
  delete process.env.SERVICE_NAME;
  delete process.env.COMPONENT;
});

test("createEvent rejects missing type or partitionKey", () => {
  assert.throws(() => createEvent({ partitionKey: "x" }), /type is required/);
  assert.throws(() => createEvent({ type: "X" }), /partitionKey is required/);
});

test("createEvent honours explicit id and extra tags", () => {
  const envelope = createEvent({
    type: "X",
    partitionKey: 42,
    id: "explicit",
    tags: { region: "eu-west-2" },
  });
  assert.equal(envelope.id, "explicit");
  assert.equal(envelope.partitionKey, "42");
  assert.equal(envelope.tags.region, "eu-west-2");
});

test("createFaultEvent carries err and uow with type fault", () => {
  const err = new Error("boom");
  const envelope = createFaultEvent(err, { messageId: "m-1", body: "{}" });
  assert.equal(envelope.type, "fault");
  assert.equal(envelope.err.name, "Error");
  assert.equal(envelope.err.message, "boom");
  assert.ok(envelope.err.stack.length > 0);
  assert.deepEqual(envelope.uow, { messageId: "m-1", body: "{}" });
});

test("createFaultEvent truncates enormous stacks", () => {
  const err = new Error("big");
  err.stack = "x".repeat(10000);
  const envelope = createFaultEvent(err, {});
  assert.equal(envelope.err.stack.length, 4096);
});
