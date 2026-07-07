const PUT_EVENTS_BATCH_LIMIT = 10;

let defaultSend;

// The AWS SDK v3 is provided by the Lambda Node.js runtime, so it is not a
// package dependency. It is imported lazily so unit tests (which always
// inject a fake client) never need it installed.
const getDefaultSend = async () => {
  if (!defaultSend) {
    const { EventBridgeClient, PutEventsCommand } = await import("@aws-sdk/client-eventbridge");
    const eventBridge = new EventBridgeClient({});
    defaultSend = (input) => eventBridge.send(new PutEventsCommand(input));
  }
  return defaultSend;
};

const chunk = (items, size) => {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
};

// Publish envelopes to the subsystem hub. Throws when EventBridge reports any
// failed entry, so callers (the listener/trigger factories) surface the whole
// unit of work as retryable rather than half-publishing silently.
//
// An injected `client` must expose `send(input)` taking the plain PutEvents
// input object - this is what unit tests fake.
export const publishEvents = async (
  events,
  {
    busName = process.env.EVENT_BUS_NAME,
    source = process.env.EVENT_SOURCE ?? process.env.SERVICE_NAME,
    client,
  } = {},
) => {
  const list = [].concat(events ?? []).filter(Boolean);
  if (list.length === 0) return;
  if (!busName) throw new Error("publishEvents: no bus name (set EVENT_BUS_NAME)");
  if (!source) throw new Error("publishEvents: no source (set EVENT_SOURCE or SERVICE_NAME)");

  const send = client ? (input) => client.send(input) : await getDefaultSend();

  for (const batch of chunk(list, PUT_EVENTS_BATCH_LIMIT)) {
    const response = await send({
      Entries: batch.map((envelope) => ({
        EventBusName: busName,
        Source: source,
        DetailType: envelope.type,
        Detail: JSON.stringify(envelope),
      })),
    });
    if (response?.FailedEntryCount > 0) {
      const failures = (response.Entries ?? [])
        .filter((entry) => entry.ErrorCode)
        .map((entry) => `${entry.ErrorCode}: ${entry.ErrorMessage}`);
      throw new Error(
        `publishEvents: ${response.FailedEntryCount} entries failed (${failures.join("; ")})`,
      );
    }
  }
};
