import { test } from "node:test";
import assert from "node:assert/strict";
import { publishEvents } from "../src/publish.js";
import { createEvent } from "../src/envelope.js";

const envelope = (type, key) => createEvent({ type, partitionKey: key, timestamp: 1 });

const fakeClient = (responses = []) => {
  const calls = [];
  return {
    calls,
    send: async (input) => {
      calls.push(input);
      return responses.shift() ?? { FailedEntryCount: 0 };
    },
  };
};

test("entries are shaped for EventBridge with the envelope in Detail", async () => {
  const client = fakeClient();
  await publishEvents([envelope("OrderPlaced", "order-1")], {
    busName: "hub",
    source: "order.checkout",
    client,
  });
  assert.equal(client.calls.length, 1);
  const entry = client.calls[0].Entries[0];
  assert.equal(entry.EventBusName, "hub");
  assert.equal(entry.Source, "order.checkout");
  assert.equal(entry.DetailType, "OrderPlaced");
  assert.equal(JSON.parse(entry.Detail).partitionKey, "order-1");
});

test("more than ten events are chunked into batches of ten", async () => {
  const client = fakeClient();
  const events = Array.from({ length: 23 }, (_, i) => envelope("E", `k-${i}`));
  await publishEvents(events, { busName: "hub", source: "s", client });
  assert.deepEqual(
    client.calls.map((call) => call.Entries.length),
    [10, 10, 3],
  );
});

test("failed entries raise with the error codes", async () => {
  const client = fakeClient([
    {
      FailedEntryCount: 1,
      Entries: [{ ErrorCode: "ThrottlingException", ErrorMessage: "slow down" }],
    },
  ]);
  await assert.rejects(
    publishEvents([envelope("E", "k")], { busName: "hub", source: "s", client }),
    /ThrottlingException: slow down/,
  );
});

test("no events is a no-op and never touches the client", async () => {
  const client = fakeClient();
  await publishEvents([], { busName: "hub", source: "s", client });
  await publishEvents(undefined, { busName: "hub", source: "s", client });
  assert.equal(client.calls.length, 0);
});

test("bus name and source fall back to the module environment variables", async () => {
  process.env.EVENT_BUS_NAME = "env-hub";
  process.env.SERVICE_NAME = "checkout";
  delete process.env.EVENT_SOURCE;
  const client = fakeClient();
  await publishEvents([envelope("E", "k")], { client });
  assert.equal(client.calls[0].Entries[0].EventBusName, "env-hub");
  assert.equal(client.calls[0].Entries[0].Source, "checkout");
  delete process.env.EVENT_BUS_NAME;
  delete process.env.SERVICE_NAME;
});

test("a single envelope may be passed without an array", async () => {
  const client = fakeClient();
  await publishEvents(envelope("E", "k"), { busName: "hub", source: "s", client });
  assert.equal(client.calls[0].Entries.length, 1);
});

test("missing configuration fails fast", async () => {
  delete process.env.EVENT_BUS_NAME;
  delete process.env.EVENT_SOURCE;
  delete process.env.SERVICE_NAME;
  await assert.rejects(publishEvents([envelope("E", "k")], { client: fakeClient() }), /no bus name/);
  await assert.rejects(
    publishEvents([envelope("E", "k")], { busName: "hub", client: fakeClient() }),
    /no source/,
  );
});
