# Micro-Frontend Manifest Deployer

> **Full documentation:** [docs/patterns/micro-frontend.md](../../../docs/patterns/micro-frontend.md): what it builds, how fragments are assembled, inputs and outputs, and when to use it.

Maps to Chapter 3 of *Software Architecture Patterns for Serverless Systems*: the manifest deployer
that aggregates per-micro-app `mfe.json` fragments into the three master manifests
(`importmap.json`, `apps.json`, `mount-points.json`) served by the main app.

## What it builds

- An S3 bucket (public-access blocked, KMS-encrypted, versioned) with two logical regions:
  - `manifests_prefix/`: where each micro-app's CI/CD uploads its `mfe.json` after a successful
    deploy. Keys typically look like `manifests/<orgName>-<projectName>.json`.
  - `master_prefix/`: where the deployer Lambda writes the consolidated master manifests.
- A Lambda function (the deployer) packaged from a caller-supplied S3 artefact. The Lambda runs
  on every `s3:ObjectCreated:*` for `manifests_prefix/*.json`, lists all fragments, merges them,
  and writes the three master files under `master_prefix/`.
- An S3 bucket notification routing matching writes to the Lambda, plus the matching
  `aws_lambda_permission`.
- Optional CloudFront invalidation: when `frontend_edge_distribution_id` and
  `frontend_edge_distribution_arn` are set, the Lambda receives `DISTRIBUTION_ID` as an env var
  and is granted `cloudfront:CreateInvalidation` so it can flush the cached master manifests
  immediately after a deploy.

## What's intentionally out of scope

- **The deployer Lambda code itself.** This module owns the wiring; the implementation lives in a
  Node.js (or Python) repo that emits a versioned ZIP into the artefact bucket. The book's
  reference implementation uses the same stream-processing framework as the BFF/Control Service
  patterns and is published at <https://github.com/jgilbert01/templates>.
- **CloudFront origin pointing at this bucket.** Compose with `frontend_edge` and use the manifest
  bucket as the primary origin (or a path-pattern origin) for the main app.

## Composition

```hcl
module "frontend_edge" {
  source = "../../modules/patterns/frontend_edge"
  name   = "${local.name_prefix}-edge"
  ...
}

module "micro_frontend" {
  source             = "../../modules/patterns/micro_frontend"
  name               = "${local.name_prefix}-manifests"
  deployer_artefact  = var.deployer_artefact
  frontend_edge_distribution_id  = module.frontend_edge.distribution_id
  frontend_edge_distribution_arn = module.frontend_edge.distribution_arn
  tags = local.tags
}
```
