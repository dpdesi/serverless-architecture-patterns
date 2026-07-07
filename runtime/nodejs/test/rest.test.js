import { test } from "node:test";
import assert from "node:assert/strict";
import { createRestHandler, json } from "../src/rest.js";

const httpEvent = (method, rawPath, { body, headers, query, claims } = {}) => ({
  rawPath,
  body,
  headers: headers ?? { "content-type": "application/json" },
  queryStringParameters: query,
  requestContext: {
    http: { method },
    ...(claims ? { authorizer: { jwt: { claims } } } : {}),
  },
});

test("routes match method and path with parameters", async () => {
  const handler = createRestHandler({
    "GET /things/{id}": async ({ pathParameters }) => json(200, { id: pathParameters.id }),
    "POST /things": async ({ body }) => json(201, body),
  });

  const get = await handler(httpEvent("GET", "/things/th-1"));
  assert.equal(get.statusCode, 200);
  assert.deepEqual(JSON.parse(get.body), { id: "th-1" });

  const post = await handler(httpEvent("POST", "/things", { body: JSON.stringify({ name: "x" }) }));
  assert.equal(post.statusCode, 201);
  assert.deepEqual(JSON.parse(post.body), { name: "x" });
});

test("unmatched requests return 404 with a helpful message", async () => {
  const handler = createRestHandler({ "GET /things": async () => json(200, []) });
  const result = await handler(httpEvent("DELETE", "/things/th-1"));
  assert.equal(result.statusCode, 404);
  assert.match(JSON.parse(result.body).message, /DELETE \/things\/th-1/);
});

test("handler errors become 500 unless onError overrides", async () => {
  const boom = async () => {
    throw new Error("boom");
  };
  const plain = createRestHandler({ "GET /x": boom });
  assert.equal((await plain(httpEvent("GET", "/x"))).statusCode, 500);

  const custom = createRestHandler(
    { "GET /x": boom },
    { onError: (err) => json(400, { message: err.message }) },
  );
  const result = await custom(httpEvent("GET", "/x"));
  assert.equal(result.statusCode, 400);
  assert.equal(JSON.parse(result.body).message, "boom");
});

test("JWT claims and query parameters reach the route context", async () => {
  const handler = createRestHandler({
    "GET /me": async ({ claims, query }) => json(200, { sub: claims.sub, page: query.page }),
  });
  const result = await handler(
    httpEvent("GET", "/me", { query: { page: "2" }, claims: { sub: "user-1" } }),
  );
  assert.deepEqual(JSON.parse(result.body), { sub: "user-1", page: "2" });
});

test("base64-encoded JSON bodies are decoded", async () => {
  const handler = createRestHandler({
    "POST /things": async ({ body }) => json(201, body),
  });
  const event = httpEvent("POST", "/things", {
    body: Buffer.from(JSON.stringify({ ok: true })).toString("base64"),
  });
  event.isBase64Encoded = true;
  const result = await handler(event);
  assert.deepEqual(JSON.parse(result.body), { ok: true });
});

test("ANY method routes match every verb", async () => {
  const handler = createRestHandler({ "ANY /health": async () => json(200, { ok: true }) });
  for (const method of ["GET", "POST", "PUT"]) {
    assert.equal((await handler(httpEvent(method, "/health"))).statusCode, 200);
  }
});

test("at least one route is required", () => {
  assert.throws(() => createRestHandler({}), /at least one route/);
});
