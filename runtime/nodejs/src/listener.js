import { createFaultEvent } from "./envelope.js";
import { isNonRetryable } from "./errors.js";
import { publishEvents } from "./publish.js";

// Parse one SQS record whose body is a full EventBridge event (the shape the
// hub delivers into listener queues). Exposed for handlers that need the raw
// shape; the factory below calls it for you.
export const parseHubRecord = (record) => {
  const eventBridgeEvent = JSON.parse(record.body);
  return {
    id: eventBridgeEvent.id,
    type: eventBridgeEvent["detail-type"],
    source: eventBridgeEvent.source,
    time: eventBridgeEvent.time,
    detail: eventBridgeEvent.detail,
    raw: eventBridgeEvent,
  };
};

// Listener contract (see docs/runtime-contract.md):
//   - retryable failure  -> report the record in batchItemFailures (SQS
//     redelivers; the redrive policy DLQs it after maxReceiveCount)
//   - non-retryable      -> publish a fault event and let the record delete
//   - fault publish fails-> fall back to batchItemFailures so nothing drops
export const createListenerHandler = ({ onEvent, publish = publishEvents } = {}) => {
  if (typeof onEvent !== "function") {
    throw new Error("createListenerHandler: onEvent function is required");
  }
  return async (event, context) => {
    const batchItemFailures = [];
    for (const record of event?.Records ?? []) {
      try {
        await onEvent(parseHubRecord(record), { record, context });
      } catch (err) {
        if (isNonRetryable(err)) {
          try {
            await publish([
              createFaultEvent(err, { messageId: record.messageId, body: record.body }),
            ]);
          } catch {
            batchItemFailures.push({ itemIdentifier: record.messageId });
          }
        } else {
          batchItemFailures.push({ itemIdentifier: record.messageId });
        }
      }
    }
    return { batchItemFailures };
  };
};
