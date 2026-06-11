// BFF listener - consumes events the hub routes into this BFF's queue (SQS
// event source mapping) and materialises them into the owned table (CQRS).
// Return ReportBatchItemFailures-shaped results so only failed records retry.
export const handler = async (event) => {
  const batchItemFailures = [];
  for (const record of event.Records ?? []) {
    try {
      // TODO: materialise record.body into the read model.
      void record;
    } catch {
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }
  return { batchItemFailures };
};
