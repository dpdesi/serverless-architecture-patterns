# ADR 0001: DynamoDB Streams Versus Kinesis

## Status

Accepted for Phase 1.

## Context

BFF services usually own their data and need to publish events when that data changes. Control Services and ESG services often process higher-throughput event streams and may need replay or multiple independent consumers.

## Decision

Use DynamoDB Streams by default for service-owned table change capture. Use Kinesis when ordering, replay duration, throughput, or multiple independent consumers exceed DynamoDB Streams constraints.

## Guidance

Choose DynamoDB Streams when:

- The source of truth is a DynamoDB table owned by the service.
- Change events only need short retention.
- A small number of consumers is sufficient.
- Database-first publication keeps the BFF workflow simple.

Choose Kinesis when:

- Multiple independent consumers need the same stream.
- Replay windows longer than DynamoDB Streams retention are required.
- Throughput, partition control, or stream analytics are primary drivers.
- A Control Service or ESG needs stream-first processing.

## Consequences

DynamoDB Streams keeps Phase 1 simple and close to the BFF data lifecycle. Kinesis remains the planned option for Phase 2 ESG and Control Service modules.
