# Subsystem app — paved-road template

A complete, copy-and-go application repo for one autonomous serverless subsystem. You describe the subsystem in [`infra/terraform/subsystem.yaml`](infra/terraform/subsystem.yaml); the [patterns library](https://github.com/dpdesi/serverless-architecture-patterns) composes ~200 AWS resources from it; your own GitOps pipeline plans, gates on a human, and applies.

This is the destination of the agentic flow (the agent authors `subsystem.yaml` and creates a repo from this template) **and** the DIY path (an engineer copies it and edits the manifest). Both converge here.

## What's in it

```
infra/terraform/   one module call + the us-east-1 edge slot; backend = S3
  subsystem.yaml   THE file you edit - the manifest
services/          co-located Lambda source, one dir per component (default)
.github/workflows/ manage-infra (plan/apply, gated) · ci · state-bucket
scripts/           build-artefacts (manifest-driven) · iac-role (OIDC bootstrap)
```

The Terraform root is tiny on purpose — almost all of it is `module "subsystem"`. The library is a **pinned dependency** (`?ref=v0.2.0`); state and apply live here, never in the library.

## Code: co-located by default, external when you want

Lambda code lives in `services/<service>/<component>/` and the deploy builds and publishes it automatically — the right default when one team owns the subsystem. When a component is owned by another team with its own release cadence, point its manifest entry at an externally-published artefact instead and the build skips it. See [`services/README.md`](services/README.md). Match the repo boundary to the team boundary, not to architectural purity.

## First deploy

One-time per AWS account (admin creds):

1. **Tag the library** at the version this template pins (`v0.2.0`) — never deploy a root that tracks a moving branch.
2. Run **scripts/iac-role.sh** — `ORG=<org> REPO=<repo> ./scripts/iac-role.sh` (creates the OIDC provider + deploy role, no stored keys).
3. Run the **Provision state bucket** workflow.
4. Create the **artefact bucket** named in `subsystem.yaml` (`artefact_defaults.bucket`).

Per GitHub Environment (dev/staging/prod):

5. Set Variables: `AWS_ACCOUNT_ID` (required), `AWS_REGION`, `IAC_ROLE_NAME`. Add **required reviewers** to the prod environment — that approval is the apply gate.

Then:

6. Edit `subsystem.yaml` (and add real handlers under `services/`).
7. Run **Manage infrastructure** → `plan` (review), then `apply` (waits for the environment approval).

## Editing the subsystem

Everything is driven by the manifest. Add a BFF, a control service (event-reactor or saga), an ESG, or switch on the public edge by following the schema (autocomplete works in editors that honour the `$schema` line) and the fully worked **payouts** example in the library. Add or remove a service → add or remove its `services/<name>/` directory. The composer and the build step both read the same manifest, so they never drift.
