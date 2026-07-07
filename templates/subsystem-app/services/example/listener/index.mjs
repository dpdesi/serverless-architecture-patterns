// BFF listener - consumes events the hub routes into this BFF's queue (SQS
// event source mapping) and materialises them into the owned table (CQRS).
// Return ReportBatchItemFailures-shaped results so only failed records retry.
// Full obligations (idempotency, order tolerance, fault events for poison
// messages) are defined by the library's docs/runtime-contract.md; the
// @atrium/service-runtime package implements them for you.
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
