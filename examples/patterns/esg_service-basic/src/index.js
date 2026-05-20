exports.handler = async event => ({
  statusCode: 202,
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ accepted: true, component: process.env.COMPONENT, event })
});
