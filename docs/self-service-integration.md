# Self-service and agentic integration

This document is a handover for whoever owns the internal AI platform (the Task Builder / supervisor agent). It explains how to drive the manifest abstraction from a conversational interface, reusing the platform's existing **AWS Infrastructure Flow** shape.

## The contract

There is exactly one contract between any front-end and this library: the **subsystem manifest**, validated against [`schema/subsystem.schema.json`](../schema/subsystem.schema.json). Anything that can produce a schema-valid `subsystem.yaml` can drive the whole library. The agent never writes Terraform — it writes a manifest, and the deterministic composer (`modules/composition/subsystem`) does the rest. That keeps the agent's blast radius to a YAML file that is schema-validated and human-reviewed in a PR.

## Mapping onto the existing AWS Infrastructure Flow

The platform's template already has the right shape (collect input → fetch template → process variables → branch → PR → Jira → Webex). Only the middle changes:

| Existing step | Becomes |
| --- | --- |
| Collect infrastructure parameters (flat form fields) | **Describe the subsystem** — conversational elicitation; the agent emits `subsystem.yaml` |
| Fetch Terraform template | *(removed — the template is the composer, already in the repo)* |
| Process template variables | **Validate manifest** against the schema |
| Create branch / commit / PR | unchanged — commit `subsystems/<name>/subsystem.yaml` + a tiny generated root |
| Create Jira ticket / Send Webex | unchanged |

The branch/PR/Jira/Webex tail is exactly today's GitOps flow. The two new pieces are elicitation and schema validation.

## Two ways to wire it

**Option A — call the repo workflow (least code).** The platform's GitHub connector runs:

```
gh workflow run subsystem-pr.yml -f manifest="$(cat subsystem.yaml)" -f region=eu-west-2
```

The [`subsystem-pr`](../.github/workflows/subsystem-pr.yml) workflow validates, renders the root, runs `terraform validate`, and opens the PR. The platform then attaches Jira/Webex as it does now. This reuses the repo's own validation and rendering — nothing to maintain on the platform side.

**Option B — render in the platform.** If you want the PR authored by your existing connector, replicate the three render steps the workflow does (validate with `check-jsonschema`, write `subsystems/<name>/{versions,variables,main,outputs}.tf`, `terraform validate`) and commit through your connector. More control, more to maintain.

Prefer Option A unless you need the PR to look identical to today's.

## The elicitation step

Give the supervisor agent three things as tools/knowledge:

1. **The schema** (`schema/subsystem.schema.json`) — so it emits valid manifests and can self-correct. Most JSON-Schema-aware models will fill required fields and respect enums/patterns if the schema is in context.
2. **A worked example** (`examples/systems/payouts-subsystem/subsystem.yaml`) — few-shot anchor for tone and structure.
3. **The pattern vocabulary** — the **Pattern Icons** page and per-pattern tabs of `docs/architecture/patterns-clean.drawio`, plus the book. This is where the agent earns its keep: translating "payouts needs a compliance check before money moves, and a gateway to our bank" into `controls: [{ mode: event_reactor, subscribes: [PayoutRequested] }]` and `esgs: [{ name: banking-rails, egress: [TransferInstructed] }]`. Load the pattern docs into the platform's Knowledge Base so the agent can also answer "which pattern do I need?" during the conversation.

### Suggested system prompt skeleton

> You help engineers describe an autonomous serverless subsystem as a `subsystem.yaml` manifest for the serverless-architecture-patterns library. Elicit: the user activities (each becomes a BFF), the decisions/orchestration the subsystem makes (control services — reactors for "derive an event from events", Step Functions sagas for multi-step processes with waits/compensation), the external systems it talks to (ESG gateways), and which events flow between them. Map everything to the manifest schema provided. Never write Terraform. Produce only a manifest that validates against the schema; if unsure which pattern fits, ask, and consult the pattern knowledge base. Default the operations block on (event lake, fault monitor, observability). Flag that artefact buckets, notification emails and any Step Functions definition are placeholders the team fills before applying.

## Guardrails worth keeping

- **The PR is the gate.** The workflow only validates and renders; a human merges and your pipeline applies. The agent cannot deploy.
- **Schema validation is non-negotiable** — it runs in the workflow and in CI (`manifest schema` job), so a malformed manifest never becomes a PR.
- **Artefacts stay the team's responsibility.** The library is source-code free; the manifest references S3 artefact locations your CI/CD publishes. The agent should never invent bucket contents.
- **Payments-specific:** remind users that idempotency keys must travel in event detail (the architecture retries at several layers) and that a real Step Functions definition is required for sagas — the module ships a no-op placeholder.
