# DynamoDB Table Primitive

> **Full documentation:** [docs/patterns/primitives.md](../../../docs/patterns/primitives.md#dynamodb-table): all four primitives, what each builds, inputs and outputs.

Creates an encrypted DynamoDB table for autonomous service persistence.

## Defaults

- `PAY_PER_REQUEST` billing.
- DynamoDB Streams enabled with `NEW_AND_OLD_IMAGES`.
- Point-in-time recovery enabled.
- Deletion protection enabled.
- Server-side encryption enabled.
