import { createHash } from "node:crypto";

const STACK_LIMIT_BYTES = 4096;

// Deterministic UUID-shaped id from the identifying parts of a fact. Same
// inputs always produce the same id, which is what lets consumers treat a
// replayed or duplicated publish as the same fact (conditional writes keyed on
// the id become no-ops on the second delivery).
export const deterministicId = (...parts) => {
  if (parts.length === 0) {
    throw new Error("deterministicId requires at least one part");
  }
  const hex = createHash("sha256").update(parts.map(String).join("|")).digest("hex");
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join("-");
};

// Build a contract-shaped envelope. `type`, `partitionKey` and `data` come
// from the caller; identity and provenance are derived unless overridden.
export const createEvent = ({
  type,
  data,
  partitionKey,
  id,
  timestamp = Date.now(),
  tags = {},
} = {}) => {
  if (!type) throw new Error("createEvent: type is required");
  if (partitionKey === undefined || partitionKey === null) {
    throw new Error("createEvent: partitionKey is required");
  }
  return {
    id: id ?? deterministicId(type, partitionKey, timestamp),
    type,
    timestamp,
    partitionKey: String(partitionKey),
    tags: {
      ...(process.env.SERVICE_NAME ? { service: process.env.SERVICE_NAME } : {}),
      ...(process.env.COMPONENT ? { component: process.env.COMPONENT } : {}),
      ...tags,
    },
    data,
  };
};

// Build a fault event carrying the failed unit of work so an operator can
// resubmit it once the cause is fixed. The type is the literal "fault" so the
// fault monitor's default rule (detail-type = ["fault"]) matches it. The
// stack is truncated so the entry stays well inside EventBridge's 256 KB cap.
export const createFaultEvent = (err, uow, { partitionKey = "fault", tags = {} } = {}) => {
  const envelope = createEvent({
    type: "fault",
    partitionKey,
    tags: {
      ...(process.env.AWS_LAMBDA_FUNCTION_NAME
        ? { functionName: process.env.AWS_LAMBDA_FUNCTION_NAME }
        : {}),
      ...tags,
    },
  });
  envelope.err = {
    name: err?.name ?? "Error",
    message: err?.message ?? String(err),
    ...(typeof err?.stack === "string" ? { stack: err.stack.slice(0, STACK_LIMIT_BYTES) } : {}),
  };
  envelope.uow = uow;
  return envelope;
};
