#!/usr/bin/env bash
# Pre-flight checks that fail with a readable message BEFORE Terraform runs,
# instead of an opaque apply-time error from Lambda fetching a missing zip.
#
# Usage:
#   scripts/preflight.sh bucket      # verify the artefact bucket exists (cheap; run before plan)
#   scripts/preflight.sh artefacts   # verify every component's zip exists (run before apply, after the build)
set -euo pipefail

MODE="${1:?usage: preflight.sh <bucket|artefacts>}"
MANIFEST="${MANIFEST:-infra/terraform/subsystem.yaml}"

# Enumerate every component's artefact location: co-located components resolve
# to the default key under artefact_defaults; explicit `artefacts:` overrides
# resolve to their own bucket/key. Mirrors modules/composition/subsystem.
python3 - "$MANIFEST" <<'PY' > /tmp/artefact-locations.tsv
import sys, yaml
m = yaml.safe_load(open(sys.argv[1])) or {}
sub = m["subsystem"]
ad = m.get("artefact_defaults") or {}
default_bucket, prefix = ad.get("bucket"), ad.get("prefix", "")
rows = []
def emit(service, comp, artefacts):
    override = (artefacts or {}).get(comp)
    if override:
        rows.append((service, comp, override["bucket"], override["key"], "external"))
    elif default_bucket:
        rows.append((service, comp, default_bucket, f"{prefix}{sub}-{service}-{comp}.zip", "co-located"))
for b in m.get("bffs") or []:
    for c in ("rest", "listener", "trigger"):
        emit(b["name"], c, b.get("artefacts"))
for c in m.get("controls") or []:
    if c.get("mode") == "event_reactor":
        for comp in ("listener", "trigger"):
            emit(c["name"], comp, c.get("artefacts"))
for e in m.get("esgs") or []:
    comps = ["ingress"] + (["egress"] if e.get("egress") else [])
    for comp in comps:
        emit(e["name"], comp, e.get("artefacts"))
for r in rows:
    print("\t".join(r))
PY

if [ ! -s /tmp/artefact-locations.tsv ]; then
  echo "No artefact-backed components in the manifest - nothing to check."
  exit 0
fi

buckets="$(cut -f3 /tmp/artefact-locations.tsv | sort -u)"
failed=0

for bucket in $buckets; do
  if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "::error::Artefact bucket 's3://$bucket' does not exist or this role cannot reach it."
    echo "         Create it with the library's modules/delivery/artefact_pipeline module (recommended:"
    echo "         it adds versioning, KMS, TLS-only access and an optional CI publisher role), or any"
    echo "         versioned private bucket, then set artefact_defaults.bucket in $MANIFEST."
    failed=1
  fi
done

if [ "$MODE" = "bucket" ] || [ "$failed" -ne 0 ]; then
  [ "$failed" -eq 0 ] && echo "Artefact bucket check passed."
  exit "$failed"
fi

missing=0
while IFS=$'\t' read -r service comp bucket key origin; do
  if ! aws s3api head-object --bucket "$bucket" --key "$key" >/dev/null 2>&1; then
    if [ "$origin" = "external" ]; then
      echo "::error::Missing external artefact for $service/$comp: s3://$bucket/$key"
      echo "         This component's manifest entry points at an externally-published zip that is not"
      echo "         there. Publish it from its owning repository, or fix the artefacts: block."
    else
      echo "::error::Missing artefact for $service/$comp: s3://$bucket/$key"
      echo "         Expected the build step to publish it from services/$service/$comp/."
      echo "         Either add source there, or declare an explicit artefacts: override in $MANIFEST."
    fi
    missing=1
  fi
done < /tmp/artefact-locations.tsv

if [ "$missing" -eq 0 ]; then
  echo "All $(wc -l < /tmp/artefact-locations.tsv | tr -d ' ') artefacts present."
fi
exit "$missing"
