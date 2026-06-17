# Event Lake Pattern

> **Full documentation:** [docs/patterns/event-lake.md](../../../docs/patterns/event-lake.md): what it builds, how facts reach S3, inputs and outputs, and when to use it.

Creates an encrypted event lake using S3 and Kinesis Data Firehose:

- Private, versioned S3 bucket.
- Public access block.
- KMS encryption with bucket keys.
- Lifecycle retention for current and non-current event objects.
- Firehose direct PUT stream with encrypted delivery and CloudWatch logging.

The event lake stores facts for replay, analytics, audit, and operational forensics.
