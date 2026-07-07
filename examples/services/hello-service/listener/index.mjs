// BFF listener component - consumes hub events this service subscribes to and
// materialises them into the owned table (CQRS). Idempotent and
// order-tolerant: a row is only written when the incoming fact is newer than
// what is already stored (inverse optimistic locking), so duplicates and
// out-of-order deliveries are no-ops.
import { createListenerHandler, NonRetryableError } from "../../../../runtime/nodejs/src/index.js";

export const createOnEvent = (store) => async (event) => {
  const envelope = event.detail;
  if (!envelope?.data?.id) {
    // Retrying cannot fix a fact with no identity - set it aside as a fault.
    throw new NonRetryableError(`event ${event.id} (${event.type}) has no data.id`);
  }
  // Strip the producer's keys before spreading: the mirrored row lives under
  // this service's own key space, not the producer's.
  const { pk: _producerPk, sk: _producerSk, ...data } = envelope.data;
  await store.putIfNewer({
    ...data,
    pk: `mirror#${envelope.data.id}`,
    sk: "MirroredThing",
    materialisedBy: "listener", // the trigger skips rows carrying this stamp
    updatedAt: envelope.timestamp,
  });
};

const defaultStore = async () => {
  const { DynamoDBClient } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient, PutCommand } = await import("@aws-sdk/lib-dynamodb");
  const documentClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
  const tableName = process.env.TABLE_NAME;
  return {
    putIfNewer: async (item) => {
      try {
        await documentClient.send(
          new PutCommand({
            TableName: tableName,
            Item: item,
            ConditionExpression: "attribute_not_exists(pk) OR updatedAt < :incoming",
            ExpressionAttributeValues: { ":incoming": item.updatedAt },
          }),
        );
      } catch (err) {
        if (err?.name !== "ConditionalCheckFailedException") throw err;
        // An equal-or-newer row is already stored: duplicate or stale delivery.
      }
    },
  };
};

let configured;
export const handler = async (event, context) => {
  configured ??= createListenerHandler({ onEvent: createOnEvent(await defaultStore()) });
  return configured(event, context);
};
