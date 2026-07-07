// Tiny router for API Gateway v2 (HTTP API) proxy events, matching the ANY
// /{proxy+} route the bff_service module wires. Route keys look like
// "GET /things/{id}"; {segments} become ctx.pathParameters.

const parseRouteKey = (routeKey) => {
  const [method, path] = routeKey.split(/\s+/);
  if (!method || !path?.startsWith("/")) {
    throw new Error(`rest: invalid route key "${routeKey}" (expected "METHOD /path")`);
  }
  return { method: method.toUpperCase(), segments: path.split("/").filter(Boolean) };
};

const matchPath = (routeSegments, pathSegments) => {
  if (routeSegments.length !== pathSegments.length) return null;
  const pathParameters = {};
  for (let i = 0; i < routeSegments.length; i += 1) {
    const routeSegment = routeSegments[i];
    if (routeSegment.startsWith("{") && routeSegment.endsWith("}")) {
      pathParameters[routeSegment.slice(1, -1)] = decodeURIComponent(pathSegments[i]);
    } else if (routeSegment !== pathSegments[i]) {
      return null;
    }
  }
  return pathParameters;
};

// JSON response helper.
export const json = (statusCode, body, headers = {}) => ({
  statusCode,
  headers: { "content-type": "application/json", ...headers },
  body: body === undefined ? "" : JSON.stringify(body),
});

const parseBody = (event) => {
  if (!event.body) return undefined;
  const contentType = event.headers?.["content-type"] ?? event.headers?.["Content-Type"] ?? "";
  const raw = event.isBase64Encoded ? Buffer.from(event.body, "base64").toString("utf8") : event.body;
  if (contentType.includes("application/json")) {
    try {
      return JSON.parse(raw);
    } catch {
      return undefined;
    }
  }
  return raw;
};

// createRestHandler({ "GET /things/{id}": async (ctx) => json(200, ...) })
// ctx: { event, pathParameters, query, body, claims }
export const createRestHandler = (routes, { onNotFound, onError } = {}) => {
  const table = Object.entries(routes ?? {}).map(([routeKey, handlerFn]) => ({
    ...parseRouteKey(routeKey),
    handlerFn,
  }));
  if (table.length === 0) throw new Error("createRestHandler: at least one route is required");

  return async (event, context) => {
    const method = event.requestContext?.http?.method?.toUpperCase();
    const pathSegments = (event.rawPath ?? "/").split("/").filter(Boolean);

    for (const route of table) {
      if (route.method !== method && route.method !== "ANY") continue;
      const pathParameters = matchPath(route.segments, pathSegments);
      if (pathParameters === null) continue;
      try {
        return await route.handlerFn({
          event,
          context,
          pathParameters,
          query: event.queryStringParameters ?? {},
          body: parseBody(event),
          claims: event.requestContext?.authorizer?.jwt?.claims ?? {},
        });
      } catch (err) {
        if (onError) return onError(err, { event, context });
        return json(500, { message: "internal error" });
      }
    }
    if (onNotFound) return onNotFound({ event, context });
    return json(404, { message: `no route for ${method} ${event.rawPath}` });
  };
};
