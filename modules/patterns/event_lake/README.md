# Event Lake Pattern

Creates an encrypted event lake using S3 and Kinesis Data Firehose:

- Private, versioned S3 bucket.
- Public access block.
- KMS encryption with bucket keys.
- Lifecycle retention for current and non-current event objects.
- Firehose direct PUT stream with encrypted delivery and CloudWatch logging.

The event lake stores facts for replay, analytics, audit, and operational forensics.
