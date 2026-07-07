# `terraform-deploy` composite action

The reusable core of "manage infrastructure": OIDC auth → `terraform init` (S3 backend, native lockfile) → `plan` / `apply` / `destroy-plan` / `destroy`. One source, referenced by every app repo, so the deploy mechanics are not copy-pasted.

It is deliberately **app-agnostic**: it does not build artefacts and does not own the trigger, permissions, or approval gate. Those belong to the calling workflow.

## What the caller owns (and why)

A composite action cannot declare `on:`, `permissions:`, `concurrency:`, or `environment:`. For an infra pipeline those are exactly the things you want standardised but also exactly the things only a *workflow* can set — most importantly the **GitHub Environment approval gate**, which is the human control point before an apply. So each app repo keeps a thin `manage-infra.yml` that owns those and calls this action for the Terraform work.

## Caller pattern (the template's `manage-infra.yml`)

```yaml
name: Manage infrastructure
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options: [plan, apply, destroy-plan, destroy]
        default: plan
      environment:
        type: environment
        default: dev

permissions:
  id-token: write      # OIDC - cannot live in the action
  contents: read

concurrency:
  group: infra-${{ inputs.environment }}
  cancel-in-progress: false

jobs:
  manage:
    runs-on: ubuntu-24.04
    environment: ${{ inputs.environment }}   # <-- the human approval gate
    steps:
      - uses: actions/checkout@v6

      # Build the subsystem's Lambda artefacts here (one zip per BFF/control/ESG
      # component the manifest references) and upload them to the artefact bucket.
      # This step is subsystem-specific and stays in the app repo / template.

      - uses: dpdesi/serverless-architecture-patterns/.github/actions/terraform-deploy@v0.2.1
        with:
          command:      ${{ inputs.action }}
          aws-region:   ${{ vars.AWS_REGION || 'eu-west-2' }}
          aws-role-arn: arn:aws:iam::${{ vars.AWS_ACCOUNT_ID }}:role/${{ vars.IAC_ROLE_NAME || 'atriumIaC' }}
          state-bucket: atrium-tfstate-${{ vars.AWS_ACCOUNT_ID }}
          state-key:    ${{ github.event.repository.name }}/${{ inputs.environment }}.tfstate
          plan-args:    -var=region=${{ vars.AWS_REGION || 'eu-west-2' }}
```

Per GitHub Environment (dev/staging/prod), set the Variables the caller reads: `AWS_ACCOUNT_ID` (required), `AWS_REGION`, `IAC_ROLE_NAME`. The state bucket and the OIDC role are bootstrapped once per account (the `state-bucket` workflow and `iac-role` script from the project-atrium pattern).

## Inputs

| Input | Required | Default | |
|---|---|---|---|
| `command` | yes | — | `plan` \| `apply` \| `destroy-plan` \| `destroy` |
| `aws-region` | yes | — | credentials + backend region |
| `aws-role-arn` | yes | — | role assumed via OIDC |
| `state-bucket` | yes | — | S3 bucket for remote state |
| `state-key` | yes | — | e.g. `payouts/dev.tfstate` |
| `working-directory` | no | `infra/terraform` | the Terraform root |
| `terraform-version` | no | `1.14.1` | |
| `plan-args` | no | `""` | extra args, e.g. `-var=region=eu-west-2` |

## Note on placement

This lives in the patterns library for now so it is immediately referenceable. The cleaner long-term home is a shared org tooling repo (e.g. an `avaloridp/.github` or `avaloridp/github-actions`); relocating is a one-line change to the `uses:` ref in each caller.
