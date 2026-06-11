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
| Create branch / commit / PR | **Get the manifest into the app repo** — scaffold a new app repo from the template, or PR `infra/terraform/subsystem.yaml` into an existing one |
| Create Jira ticket / Send Webex | unchanged |

The Jira/Webex tail is exactly today's GitOps flow. The new pieces are elicitation, schema validation, and landing the manifest in the *app* repo (never in this library — the library is only ever a pinned dependency).

## Two ways to land the manifest

**Option A — call the `author-subsystem` workflow (least platform code).**

```
gh workflow run author-subsystem.yml \
  -f target_repo=<org>/<app> -f create_if_missing=true \
  -f manifest="$(cat subsystem.yaml)"
```

The [`author-subsystem`](../.github/workflows/author-subsystem.yml) workflow validates the manifest, then either scaffolds a new app repo from `templates/subsystem-app` (greenfield) or opens a PR adding/updating the manifest in an existing app repo (brownfield). Because it writes into another repo it needs the `SUBSYSTEM_AUTHOR_TOKEN` secret (a GitHub App/PAT with repo admin on the target org). The platform attaches Jira/Webex afterwards.

**Option B — the platform's own GitHub connector.** Your Task Builder already does "create branch / commit / PR." Point it at the app repo: write `infra/terraform/subsystem.yaml` to a branch via the Contents API and open a PR, creating the repo from the template first if greenfield. Same result, authored by your connector, no shared token needed. This is the transport to prefer if you want the PR to look identical to today's.

Either way the contract is fixed: **`infra/terraform/subsystem.yaml` in the app repo, PR-gated, human-merged.**

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
