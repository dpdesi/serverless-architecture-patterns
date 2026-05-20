exports.handler = async event => {
  const body = typeof event.body === "string" && event.body.length > 0
    ? JSON.parse(event.body)
    : { ok: true };

  return {
    statusCode: 200,
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      ok: true,
      component: process.env.COMPONENT || "smoke",
      service: process.env.SERVICE_NAME,
      input: body
    })
  };
};
