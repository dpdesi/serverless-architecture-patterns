# HTTP API Primitive

> **Full documentation:** [docs/patterns/primitives.md](../../../docs/patterns/primitives.md#http-api): all four primitives, what each builds, inputs and outputs.

Creates an API Gateway HTTP API with Lambda proxy integrations and optional JWT authorisation.

## Defaults

- HTTP API rather than REST API.
- Access logs enabled with finite retention.
- Optional CORS configuration.
- Optional JWT authoriser for OIDC providers.
- Per-route Lambda invoke permissions.
