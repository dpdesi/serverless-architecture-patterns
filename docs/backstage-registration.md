# Backstage Registration

The Phase 1 templates live in:

- `templates/backstage/new-subsystem`
- `templates/backstage/new-bff-service`
- `templates/backstage/new-esg-service`
- `templates/backstage/new-control-service`

Register each `template.yaml` in your Backstage software catalogue. Generated skeletons include:

- Terraform root stack.
- Example tfvars.
- README.
- Documentation stub.
- `catalog-info.yaml`.
- CI workflow.
- Test stub.

The CLI fallback in `templates/cli/scaffold` renders equivalent output when Backstage is unavailable.

## Required Template Values

- `system_name`
- `subsystem_name`
- `service_type`
- `owner`
- `description`
- `primary_region`
- `secondary_region`
- `environment_tiers`
- `auth_mode`
- `event_transport`
- `workflow_mode`
- `artefact_registry`
- `use_localstack`
- `publish_to_registry`
- `observability_sink`
