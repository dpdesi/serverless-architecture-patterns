# Serverless subsystem

A starter repository for building one **autonomous, event-driven serverless subsystem on AWS**, a self-contained slice of a system (say *payments*, *orders*, or *onboarding*) that owns its own data and APIs and collaborates with the rest of the world through events rather than direct calls.

You describe *what* the subsystem needs in a single YAML file. A versioned Terraform pattern library turns that into the ~200 AWS resources that implement it: the APIs, functions, databases, event routing, queues, dead-letter queues, encryption, IAM and observability, all wired together with sensible, secure defaults. You write your application code and the manifest; you don't hand-write Terraform.

> New to this architecture? Skim the [pattern library](https://github.com/dpdesi/serverless-architecture-patterns) and its [architecture diagram](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/docs/architecture/patterns-clean.drawio) first. The **Pattern Icons** page is a one-glance key to every building block referenced below.

---

## What you get

Every subsystem is assembled from a small set of building blocks. You choose which ones you need in the manifest:

| Block | What it is |
| --- | --- |
| **Event hub** | A private event bus at the centre of the subsystem. Services publish facts to it and subscribe to the events they care about; they never call each other directly. This is what makes the subsystem resilient: one service failing doesn't cascade. |
| **BFF** (Backend for Frontend) | A service for a single user-facing activity. It's an HTTP API + functions + its own database, plus the plumbing to publish its changes as events and to build read-models from events it subscribes to. One BFF per activity (e.g. *checkout*, *account*). |
| **Control service** | A service that reacts to events to make a decision or run a process. Two modes: an **event-reactor** (derive a new event from observed ones, e.g. "approve or reject this payout") or a **saga** (a Step Functions workflow for a multi-step process with waits, retries and compensation). |
| **ESG** (External Service Gateway) | An anti-corruption boundary around an external system such as a payment provider or partner API. It normalises inbound webhooks into your events and delivers your outbound events to the external API, so external quirks never leak into the rest of the subsystem. |
| **Operations** | Cross-cutting infrastructure, on by default: an immutable **event lake** (audit trail you can replay), a **fault monitor** (catches failure events for resubmission), and an **observability baseline** (alarms, dashboards, tracing). Optional **regional health checks** for failover. |

Each block carries the library's security defaults automatically: customer-managed KMS encryption everywhere, least-privilege IAM, dead-letter queues on every async path, finite log retention, required tags.

---

## How it works

```
subsystem.yaml          you edit this, the description of your subsystem
      │
      ▼
pattern library         a pinned Terraform dependency that composes the resources
      │
      ▼
~200 AWS resources      created in your account by the deploy workflow
```

- **You own** the manifest (`infra/terraform/subsystem.yaml`) and your Lambda code (`services/`).
- **The library owns** the composition and the security posture. It's referenced by a pinned version, so upgrades are deliberate.
- **This repo owns** the Terraform state and the deploy. The library never deploys anything.

---

## Prerequisites

You need an AWS account and a GitHub repository (this one). Set up once:

**Per AWS account** (run with admin credentials for that account):

1. **A deploy role**: run [`scripts/iac-role.sh`](scripts/iac-role.sh) (`ORG=<your-org> REPO=<this-repo> ./scripts/iac-role.sh`). It creates the GitHub OIDC provider and an IAM role this repo's workflows assume; no long-lived AWS keys are ever stored.
2. **A state bucket**: run the **Provision state bucket** GitHub Action (Actions tab, then run workflow). Holds Terraform state, encrypted and versioned.
3. **An artefact bucket**: create the S3 bucket named in `subsystem.yaml` (`artefact_defaults.bucket`). Your Lambda zips are published here.

**Per environment** (dev / staging / prod, which are [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments)):

4. Set environment **Variables**: `AWS_ACCOUNT_ID` (required), `AWS_REGION` (default `eu-west-2`), `IAC_ROLE_NAME` (if not the default).
5. On `prod`, add **required reviewers**. That approval is your deploy gate.

> Tooling versions: Terraform `1.14.1`, Node `22`. The deploy workflow installs both.

---

## Quickstart

1. **Edit** [`infra/terraform/subsystem.yaml`](infra/terraform/subsystem.yaml) to describe your subsystem (see below). The starter is a single BFF plus the operations set, which is enough to deploy.
2. **Add your code** under `services/` (the starter ships working stubs for the example BFF).
3. Open a PR. CI validates the manifest against the schema and runs `terraform validate`.
4. Merge, then run the **Manage infrastructure** Action with `plan` and review the output.
5. Run it again with `apply` (it waits for the environment approval).

---

## Describing your subsystem

Everything is driven by `infra/terraform/subsystem.yaml`. If your editor has a YAML language server, the `$schema` line at the top of the file gives you autocomplete and inline validation for every field. The [full schema](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/schema/subsystem.schema.json) is the source of truth.

A fuller example (a payments payout subsystem) is worth reading: [`examples/systems/payouts-subsystem/subsystem.yaml`](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/examples/systems/payouts-subsystem/subsystem.yaml).

```yaml
subsystem: orders            # short name; prefixes every resource
tags:                        # propagated to everything; these three are required
  Environment: dev
  System: commerce
  Owner: orders-team

artefact_defaults:
  bucket: orders-artefacts   # where your Lambda zips are published
  prefix: lambda/

bffs:
  - name: cart               # a user activity with its own API + db + functions
    activity: crud
    path: /cart/*            # the route a CDN would send here
    publishes: [CartCheckedOut]
  - name: tracking
    activity: dashboard
    read_only: true          # its data is built from events (CQRS), not writes
    subscribes: [OrderPlaced, OrderShipped]

controls:
  - name: fulfilment
    mode: step_functions     # a saga: multi-step process with compensation
    subscribes: [OrderPlaced]

esgs:
  - name: shipping
    external: dhl            # anti-corruption boundary around a carrier API
    egress: [ShipmentRequested]
    webhook: true            # also accept inbound webhooks

operations:                  # all default to on
  event_lake: { enabled: true }
  fault_monitor: { enabled: true, emails: [oncall@example.com] }
  observability: { enabled: true }
```

The events listed under `publishes` / `subscribes` / `egress` are how blocks talk to each other: a control service `subscribes` to what a BFF `publishes`, and an ESG's `egress` matches events you want delivered to an external system. Names are yours to choose; just keep them consistent across the manifest.

---

## Adding your Lambda code

Application code lives in `services/`, one directory per component, named to match the manifest:

```
services/
  cart/              # a BFF named "cart"
    rest/            # the HTTP API handler
    listener/        # builds the read-model from subscribed events
    trigger/         # publishes the table's changes as events
  fulfilment/        # an event-reactor control would have listener/ + trigger/
  shipping/          # an ESG
    ingress/         # normalises inbound webhooks into events
    egress/          # delivers outbound events to the external API
```

The deploy workflow builds each component found here and publishes its zip to the location the library expects. **Co-location is the default**, the right choice when one team owns the whole subsystem. Add a `package.json` to a component and the build runs `npm ci` for it; otherwise it just zips the directory.

**Using code owned by another team?** Don't put its source here. Point that component at an externally-published artefact in the manifest instead and the build skips it:

```yaml
controls:
  - name: pricing
    mode: event_reactor
    subscribes: [PriceRequested]
    artefacts:
      listener: { bucket: pricing-artefacts, key: pricing/listener/1.4.2.zip }
      trigger:  { bucket: pricing-artefacts, key: pricing/trigger/1.4.2.zip }
```

Co-located and external components can coexist. Decide per component by who owns the code; see [`services/README.md`](services/README.md).

---

## Deploying

Deploys run from the **Manage infrastructure** GitHub Action (Actions tab, then run workflow). Pick an action and an environment:

- **plan**: preview the changes. Safe; makes nothing.
- **apply**: build and publish the Lambda artefacts, then apply. It waits for the environment's required reviewers before it runs.
- **destroy-plan** / **destroy**: preview, or tear down.

State is keyed per environment (`<repo>/<env>.tfstate`), so dev, staging and prod never collide. Authentication is OIDC, with no stored AWS credentials.

If your subsystem has a public frontend, set `edge.enabled: true` in the manifest; the template's root provisions CloudFront/ACM in `us-east-1` and routes your BFF APIs behind it. Otherwise that part stays dormant.

---

## Repository layout

```
infra/terraform/
  subsystem.yaml     the manifest, the file you edit most
  main.tf            one module call to the library + a dormant edge slot
  versions.tf        provider + S3 backend
services/            your Lambda code, one dir per component
scripts/
  build-artefacts.sh builds and publishes the zips (manifest-driven)
  iac-role.sh        one-time OIDC deploy-role bootstrap
.github/workflows/
  manage-infra.yml   plan / apply / destroy, behind the approval gate
  ci.yml             validates the manifest + terraform on every PR
  state-bucket.yml   one-time state bucket bootstrap
```

---

## Troubleshooting

- **`terraform init` can't find the module, or a 404 on the library**: the library is referenced by a pinned version (`?ref=v0.2.0`). Make sure that tag exists and your repo can access the library (it's a private dependency).
- **Apply fails: Lambda code not found in S3**: the artefact bucket doesn't exist, or the build didn't run. Apply (not plan) builds and uploads; check the build step's logs and that `artefact_defaults.bucket` exists.
- **Apply fails assuming the role**: the OIDC role isn't set up for this repo, or `AWS_ACCOUNT_ID` isn't set on the environment. Re-run `scripts/iac-role.sh` and check the environment Variables.
- **Manifest rejected in CI**: the `manifest schema` job tells you exactly which field is wrong. The schema is the contract.

---

## Learn more

- **Pattern library** (the building blocks and their docs): <https://github.com/dpdesi/serverless-architecture-patterns>
- **Architecture diagram** (every pattern as a glyph, plus worked examples): [`docs/architecture/patterns-clean.drawio`](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/docs/architecture/patterns-clean.drawio)
- **Manifest schema** (every field, with descriptions): [`schema/subsystem.schema.json`](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/schema/subsystem.schema.json)
- **Worked example** (a complete payments payout subsystem): [`examples/systems/payouts-subsystem`](https://github.com/dpdesi/serverless-architecture-patterns/tree/main/examples/systems/payouts-subsystem)
