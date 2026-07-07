import { createFaultEvent } from "./envelope.js";
import { isNonRetryable } from "./errors.js";
import { publishEvents } from "./publish.js";
import { unmarshall } from "./unmarshall.js";

// Parse one DynamoDB stream record into a plain change object.
export const parseStreamRecord = (record) => ({
  eventName: record.eventName, // INSERT | MODIFY | REMOVE
  keys: unmarshall(record.dynamodb?.Keys),
  newImage: unmarshall(record.dynamodb?.NewImage),
  oldImage: unmarshall(record.dynamodb?.OldImage),
  sequenceNumber: record.dynamodb?.SequenceNumber,
  raw: record,
});

// Trigger contract (see docs/runtime-contract.md): map each table change to
// zero or more envelopes via `toEvents(change)`, publish them to the hub, and
// report failures per record keyed by the stream sequence number (what the
// DynamoDB event source mapping requires for ReportBatchItemFailures).
export const createTriggerHandler = ({ toEvents, publish = publishEvents } = {}) => {
  if (typeof toEvents !== "function") {
    throw new Error("createTriggerHandler: toEvents function is required");
  }
  return async (event, context) => {
    const batchItemFailures = [];
    for (const record of event?.Records ?? []) {
      const change = parseStreamRecord(record);
      const itemIdentifier = change.sequenceNumber ?? record.eventID;
      try {
        const events = [].concat((await toEvents(change, { record, context })) ?? []);
        if (events.length > 0) {
          await publish(events);
        }
      } catch (err) {
        if (isNonRetryable(err)) {
          try {
            await publish([
              createFaultEvent(
                err,
                { eventName: change.eventName, keys: change.keys, sequenceNumber: change.sequenceNumber },
                { partitionKey: itemIdentifier },
              ),
            ]);
          } catch {
            batchItemFailures.push({ itemIdentifier });
          }
        } else {
          batchItemFailures.push({ itemIdentifier });
        }
      }
    }
    return { batchItemFailures };
  };
};
