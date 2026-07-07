// Thrown by a handler when retrying cannot possibly succeed (malformed
// payload, business-rule violation). The listener/trigger factories respond by
// publishing a fault event and letting the record leave the queue/stream,
// instead of reporting it as a batch failure and retrying it forever.
export class NonRetryableError extends Error {
  constructor(message, options) {
    super(message, options);
    this.name = "NonRetryableError";
    this.nonRetryable = true;
  }
}

// Duck-typed so handlers can mark their own error classes without importing
// ours: any error carrying `nonRetryable = true` is treated the same way.
export const isNonRetryable = (err) =>
  err?.nonRetryable === true || err?.name === "NonRetryableError";
