# Subsystem composition

> **Full documentation:** [docs/building-a-subsystem.md](../../../docs/building-a-subsystem.md): how the composer turns a manifest into a wired subsystem, walked through the examples.

Renders a complete autonomous subsystem from a single declarative manifest. This is the abstraction that sits on top of the pattern library: instead of hand-wiring `event_hub`, `bff_service`, `control_service`, `esg_service` and the operational patterns together, you describe the subsystem in `subsystem.yaml` (vocabulary matching the pattern glyphs in `docs/architecture/patterns-clean.drawio`) and this module derives all the wiring.

## Usage

```hcl
module "subsystem" {
  source = "../../modules/composition/subsystem"

  manifest = yamldecode(file("${path.module}/subsystem.yaml"))
}
```

See `examples/systems/payouts-subsystem` for a complete worked example, and `schema/subsystem.schema.json` for the manifest schema (point your editor's YAML language server at it for validation and completion).

## What the composer derives for you

These are the pieces every hand-rolled composition has to remember, and most forget:

- **One subsystem KMS key** with a key policy granting the EventBridge, CloudWatch and SNS service principals use of the key. Without those grants, EventBridge cannot deliver into SSE-KMS listener queues or DLQs and alarms cannot publish to encrypted topics.
- **Hub routes** - one rule per subscribing BFF (`detail-type` pattern from `subscribes`) plus the event-lake archive route (catch-all by default).
- **SQS queue policies** on every BFF listener queue, scoped to the exact hub rule ARN. `bff_service` deliberately knows nothing about the hub, so the composition owns this glue.
- **Per-route delivery DLQs** with the queue policies EventBridge needs to dead-letter into them.
- **The EventBridge-to-Firehose glue role** (`firehose:PutRecord`/`PutRecordBatch`) for the event-lake route.
- **Observability inputs** - every BFF, reactor-control and ESG Lambda with the correct timeout and DLQ wired into `observability_baseline`. The `default_timeouts` local mirrors the pattern modules' defaults; override both together.
- **Regional health alarms** per BFF (Lambda errors + DynamoDB system errors), created in the workload region.
- **`api_origins` output** ready to feed `frontend_edge` in an edge root.

## Edge composition

The `edge:` section of the manifest is *not* consumed by this module. CloudFront, ACM and the manifest deployer live in us-east-1 behind a provider alias, so they belong in a separate root (or module call) that reads the same manifest and this module's `api_origins` output:

```hcl
module "edge" {
  source    = "../../modules/patterns/frontend_edge"
  providers = { aws = aws.us_east_1 }

  name        = "${module.subsystem.subsystem}-edge"
  api_origins = module.subsystem.api_origins
  # aliases / certificate from manifest.edge
  tags = local.tags
}
```

## Naming budget

Every resource is prefixed `<subsystem>-<service>`. The schema caps both segments at 24 characters; the tightest downstream limits are the EventBridge archive name (48 chars) and Lambda execution role names (64 chars), both comfortably inside the budget.
