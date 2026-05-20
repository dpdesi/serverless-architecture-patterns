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
  - Zero or more **API origins** in a map. Each entry creates its own CloudFront origin and
    ordered cache behaviour for a `path_pattern` (e.g. `/api/*` or `/catalogue/*`) pointing at a
    BFF or any HTTPS endpoint, with caching disabled and the host header stripped. Use multiple
    entries to fan one public domain out to multiple per-BFF API Gateways (every `bff_service`
    instance creates its own `api_http`; this map is what unifies them behind one CloudFront URL).
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
- `api_origins` — map of `{ domain_name, path_pattern, origin_path }` entries. The map key
  becomes the CloudFront `origin_id` prefix (`api-<key>`). Example wiring for a multi-BFF
  storefront:

  ```hcl
  api_origins = {
    catalogue = { domain_name = module.catalogue_bff.api_domain_name, path_pattern = "/catalogue/*" }
    cart      = { domain_name = module.cart_bff.api_domain_name,      path_pattern = "/cart/*"      }
    checkout  = { domain_name = module.checkout_bff.api_domain_name,  path_pattern = "/checkout/*"  }
  }
  ```

  Path-pattern uniqueness and the leading `/` are validated. Note that CloudFront forwards the
  matched request path unchanged to the origin, so each BFF must be aware of its own base path
  (or attach a CloudFront Function to the returned `api_origin_ids` to strip the prefix).

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
