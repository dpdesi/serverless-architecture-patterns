# Frontend Edge Pattern

CloudFront distribution serving a single-page application from a private S3 origin, with optional
secondary-origin failover and optional BFF API routing.

Maps to Chapter 9 of *Software Architecture Patterns for Serverless Systems* (origin group + failover
criteria) and Chapter 3 (CDN serving micro-frontend artefacts).

## What it builds

- An S3 bucket hardened with public-access block, versioning, KMS server-side encryption, and a
  bucket policy that grants `s3:GetObject` only to the CloudFront distribution via Origin Access
  Control (OAC). The policy also denies any non-TLS access.
- A CloudFront distribution with:
  - The primary S3 origin via OAC.
  - An optional **secondary origin** (an S3 bucket in another region or account) grouped with the
    primary under an origin group that fails over on configurable HTTP status codes.
  - An optional **API origin** for routing a `path_pattern` (e.g. `/api/*`) to a BFF custom-domain
    endpoint with caching disabled and the host header stripped.
  - A response-headers policy applying HSTS, `X-Content-Type-Options`, `X-Frame-Options: DENY`,
    `Referrer-Policy`, and `X-XSS-Protection`.
  - SPA-friendly custom error responses (403/404 rewritten to `/index.html` with a 200) so client-
    side routing works.
  - Optional WAFv2 web ACL attachment, optional ACM custom domain aliases (must live in
    us-east-1), and optional access logging to a caller-provided log bucket.

## Inputs you usually set

- `primary_origin_bucket_name` — explicit bucket name (defaults to `${name}-primary`).
- `domain_aliases` + `acm_certificate_arn` — to serve the SPA on a custom domain.
- `secondary_origin` — `{ domain_name, origin_access_control_id }` of a peer bucket in another
  region. The peer module instance exposes both via its outputs.
- `api_origin` — `{ domain_name, path_pattern }` of the BFF behind a custom domain (or the API
  Gateway execute-api domain).

## What's intentionally out of scope

- Route 53 alias records — composed at the stack level so they can mix in regional health checks.
- The secondary origin bucket itself — created in a separate stack root for the secondary region so
  it can live behind a different provider alias.
- CloudFront access logs bucket — the legacy logging stack requires ACLs enabled, which conflicts
  with the bucket-encryption defaults this library enforces elsewhere. Pass a pre-existing log
  bucket via `access_log_bucket_domain_name` if you want logs delivered.

## Composition

This module is intended to compose with `bff_service` (for the API origin), `regional_health_check`
(for Route 53 failover wiring at the stack level), and a peer instance of itself in a secondary
region (for the origin group).
