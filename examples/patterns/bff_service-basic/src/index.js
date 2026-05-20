exports.handler = async event => ({
  statusCode: 200,
  headers: { "content-type": "application/json" },
  body: JSON.stringify({
    ok: true,
    route: event.rawPath || "/"
  })
});
