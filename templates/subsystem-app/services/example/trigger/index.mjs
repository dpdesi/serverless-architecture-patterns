// BFF trigger - consumes the owned table's DynamoDB stream and publishes
// database-first domain facts to the event hub (PutEvents). This is the
// outbound side of the bulkhead: state changes become events others react to.
export const handler = async (event) => {
  for (const record of event.Records ?? []) {
    // TODO: map the change record to a domain event and PutEvents to the hub
    // (EVENT_BUS_NAME is injected by the module as an environment variable).
    void record;
  }
  return { batchItemFailures: [] };
};
