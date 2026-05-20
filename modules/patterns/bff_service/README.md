# BFF Service Pattern

Creates a Backend for Frontend boundary service. The module accepts external Lambda artefact references and wires the infrastructure needed for a user-facing autonomous service:

- HTTP API with optional JWT authorisation.
- REST Lambda for synchronous frontend requests.
- DynamoDB table with stream enabled for database-first event publication.
- Trigger Lambda on the table stream.
- Listener SQS queue and Lambda for consuming event hub routes.
- EventBridge publish permissions to the subsystem event hub.

The module deliberately does not include application business code.
