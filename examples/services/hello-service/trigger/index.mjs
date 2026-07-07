// BFF trigger component - consumes the owned table's DynamoDB stream and
// publishes each committed change as a fact on the hub (database-first event
// publication). Rows the listener materialised are skipped so mirrored views
// never echo back onto the hub as new facts.
import { createEvent, createTriggerHandler } from "../../../../runtime/nodejs/src/index.js";

const TYPE_BY_ACTION = {
  INSERT: "ThingCreated",
  MODIFY: "ThingUpdated",
  REMOVE: "ThingDeleted",
};

export const toEvents = (change) => {
  const image = change.newImage ?? change.oldImage;
  if (!image || image.sk !== "Thing") return undefined; // only publish facts about things
  if (image.materialisedBy) return undefined; // listener-stamped rows: no echo
  return createEvent({
    type: TYPE_BY_ACTION[change.eventName],
    partitionKey: image.pk,
    timestamp: image.updatedAt ?? Date.now(),
    data: image,
  });
};

export const handler = createTriggerHandler({ toEvents });
