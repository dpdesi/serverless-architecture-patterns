# Artefact Pipeline

The first mile of the paved road. Every module in this library consumes Lambda code as an S3
artefact reference, which means a bucket must exist - and be versioned, encrypted, and writable by
CI - before anything can deploy. Until now that bucket was a "create it yourself" instruction in
the template README; this module makes it a first-class, tested building block.

![Artefact pipeline: a GitHub Actions build workflow assumes the OIDC publisher role and publishes zips into the versioned, KMS-encrypted artefact bucket; preflight.sh verifies the bucket and every expected artefact before plan and apply; Lambda fetches the code at apply time](../../../docs/architecture/patterns/artefact-pipeline.png)

*The **Artefact Pipeline** tab of [`patterns-clean.drawio`](../../../docs/architecture/patterns-clean.drawio); open the source for the editable version.*

## What it builds

- **A hardened artefact bucket**: versioning on (superseded artefact versions are the rollback
  mechanism), customer-managed KMS encryption, public access blocked, a TLS-only bucket policy,
  and a lifecycle rule expiring superseded versions after `noncurrent_version_retention_days`
  (default 90) plus abandoned multipart uploads after 7 days.
- **Optionally, a GitHub Actions publisher role** (`github_oidc`): an IAM role assumable via the
  account's `token.actions.githubusercontent.com` OIDC provider, scoped by default to every ref of
  the named repository (tighten `subjects` to a branch for production), allowed to put/get objects
  in this bucket and use its KMS key - and nothing else. The account-global OIDC *provider* is not
  created here (it usually exists once per account, e.g. via `scripts/iac-role.sh`); pass
  `provider_arn` if yours lives at a non-conventional ARN.

## Usage

```hcl
module "artefacts" {
  source = "git::https://github.com/dpdesi/serverless-architecture-patterns.git//modules/delivery/artefact_pipeline?ref=v0.2.1"

  name = "payouts-artefacts"

  github_oidc = {
    repository = "example-org/payouts-subsystem"
    # subjects = ["repo:example-org/payouts-subsystem:ref:refs/heads/main"]
  }

  tags = { Environment = "dev", System = "payments", Owner = "payouts-team" }
}
```

`bucket_name` output goes into the manifest's `artefact_defaults.bucket`; `publisher_role_arn` is
what the app repo's build workflow assumes to publish zips.

## The pre-flight checks

The subsystem-app template pairs this module with `scripts/preflight.sh`, which runs in the
`manage-infra` workflow:

- **before every plan/apply**: `preflight.sh bucket` verifies the artefact bucket exists, failing
  with instructions instead of an opaque Terraform error.
- **before apply, after the build**: `preflight.sh artefacts` verifies every component's zip
  (co-located *and* externally-published) is present at the exact key Terraform will reference,
  and names each missing one with what to do about it.

## Placement

This lives under `modules/delivery/`, not `modules/patterns/`: it is not part of a running
subsystem's architecture but of the machinery that delivers one. It is deliberately deployable
separately from (and before) the subsystem itself, typically in a small bootstrap root or the
account baseline, because the bucket must exist before the first apply of anything that references
it.
