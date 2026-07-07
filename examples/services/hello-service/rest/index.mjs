// BFF REST component - synchronous requests behind the HTTP API.
// Database-first: handlers write the owned table and return; the trigger
// component turns committed writes into facts on the hub.
import { createRestHandler, json } from "../../../../runtime/nodejs/src/index.js";

// The store is injected so tests run without AWS; the default lazily builds a
// DynamoDB Document client (the SDK ships inside the Lambda runtime).
export const createHandler = (store) =>
  createRestHandler({
    "GET /things/{id}": async ({ pathParameters }) => {
      const thing = await store.get(pathParameters.id);
      return thing ? json(200, thing) : json(404, { message: "not found" });
    },
    "PUT /things/{id}": async ({ pathParameters, body, claims }) => {
      if (!body || typeof body !== "object") {
        return json(400, { message: "a JSON body is required" });
      }
      const thing = {
        id: pathParameters.id,
        ...body,
        lastModifiedBy: claims.sub ?? "anonymous",
        updatedAt: Date.now(),
      };
      await store.put(thing);
      return json(200, thing);
    },
  });

const defaultStore = async () => {
  const { DynamoDBClient } = await import("@aws-sdk/client-dynamodb");
  const { DynamoDBDocumentClient, GetCommand, PutCommand } = await import("@aws-sdk/lib-dynamodb");
  const documentClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
  const tableName = process.env.TABLE_NAME;
  return {
    get: async (id) => {
      const { Item } = await documentClient.send(
        new GetCommand({ TableName: tableName, Key: { pk: `thing#${id}`, sk: "Thing" } }),
      );
      return Item;
    },
    put: async (thing) => {
      await documentClient.send(
        new PutCommand({
          TableName: tableName,
          Item: { pk: `thing#${thing.id}`, sk: "Thing", ...thing },
        }),
      );
    },
  };
};

let configured;
export const handler = async (event, context) => {
  configured ??= createHandler(await defaultStore());
  return configured(event, context);
};
