// BFF REST handler - synchronous user requests behind the HTTP API.
// Read/write your owned table here; publish task events to the hub if needed.
// Replace this stub with your real handler (add a package.json for dependencies
// and the build step will `npm ci` it automatically).
export const handler = async (event) => {
  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ ok: true, service: "example", component: "rest" }),
  };
};
