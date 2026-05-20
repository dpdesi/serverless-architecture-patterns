# Customer Subsystem Example

This is the Phase 1 integration path. It targets LocalStack by default and deploys a minimal customer subsystem: event hub, BFF API, DynamoDB table, listener queue, and Lambda smoke handlers.

Run:

```sh
docker compose up -d localstack
terraform init
terraform apply -auto-approve
terraform output
```

Use an ephemeral AWS dev account instead by replacing the provider configuration with normal AWS credentials and regions.
