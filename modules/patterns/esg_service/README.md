# ESG Service Pattern

Creates an External Service Gateway for anti-corruption boundaries:

- Ingress Lambda that normalises external events and publishes internal events to the subsystem event hub.
- Optional HTTP API webhook endpoint.
- Egress EventBridge rule, SQS queue, and Lambda for sending subsystem events to external systems.
- SSM Parameter Store and Secrets Manager grants for external configuration and credentials.

The module accepts artefact references only. It does not include external-system business logic.
