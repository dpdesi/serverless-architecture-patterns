# Lambda Function Primitive

> **Full documentation:** [docs/patterns/primitives.md](../../../docs/patterns/primitives.md#lambda-function): all four primitives, what each builds, inputs and outputs.

Creates a production-ready Lambda function from an external artefact reference. The module does not package source code; callers provide either an S3 ZIP artefact or a container image URI.

## Features

- One execution role per function with scoped inline permissions.
- CloudWatch log group with finite retention.
- Active X-Ray tracing by default.
- Optional encrypted SQS dead-letter queue.
- Optional SSM Parameter Store and Secrets Manager read grants.
- Required `Environment`, `System`, and `Owner` tags.

## Example

```hcl
module "handler" {
  source = "../../../modules/primitives/lambda_function"

  name      = "customer-smoke-handler"
  s3_bucket = aws_s3_bucket.artefacts.bucket
  s3_key    = aws_s3_object.handler.key

  tags = {
    Environment = "dev"
    System      = "customer"
    Owner       = "platform"
  }
}
```
