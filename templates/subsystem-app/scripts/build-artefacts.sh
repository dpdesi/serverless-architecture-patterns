#!/usr/bin/env bash
# Build and publish a Lambda zip for every co-located component the manifest
# references, then upload it to the key the composer expects.
#
# Co-location is the default: a component with source under
# services/<service>/<component>/ is built here. A component whose manifest
# entry has an explicit `artefacts:` override is treated as externally
# published and skipped - that is the escape hatch.
set -euo pipefail

MANIFEST="${MANIFEST:-infra/terraform/subsystem.yaml}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Enumerate components that use the DEFAULT (co-located) artefact key. The key
# format mirrors modules/composition/subsystem exactly.
python3 - "$MANIFEST" <<'PY' > /tmp/components.tsv
import sys, yaml
m = yaml.safe_load(open(sys.argv[1])) or {}
sub = m["subsystem"]
ad = m.get("artefact_defaults") or {}
bucket, prefix = ad.get("bucket"), ad.get("prefix", "")
rows = []
def emit(service, comp, artefacts):
    if artefacts and artefacts.get(comp):   # explicit override -> external, skip
        return
    if not bucket:
        return
    rows.append((service, comp, bucket, f"{prefix}{sub}-{service}-{comp}.zip"))
for b in m.get("bffs") or []:
    for c in ("rest", "listener", "trigger"):
        emit(b["name"], c, b.get("artefacts"))
for c in m.get("controls") or []:
    if c.get("mode") == "event_reactor":
        for comp in ("listener", "trigger"):
            emit(c["name"], comp, c.get("artefacts"))
for e in m.get("esgs") or []:
    for comp in ("ingress", "egress"):
        emit(e["name"], comp, e.get("artefacts"))
for r in rows:
    print("\t".join(r))
PY

if [ ! -s /tmp/components.tsv ]; then
  echo "No co-located components to build (all external, or none declared)."
  exit 0
fi

while IFS=$'\t' read -r service comp bucket key; do
  src="$REPO_ROOT/services/$service/$comp"
  if [ ! -d "$src" ]; then
    echo "::warning::No local source at services/$service/$comp - expecting an externally-published artefact at s3://$bucket/$key"
    continue
  fi
  echo "Building $service/$comp -> s3://$bucket/$key"
  work="$(mktemp -d)"
  cp -r "$src/." "$work/"
  if [ -f "$work/package.json" ]; then
    (cd "$work" && npm ci --omit=dev --silent)
  fi
  out="$(mktemp -d)/artefact.zip"
  (cd "$work" && zip -qr "$out" .)
  aws s3 cp "$out" "s3://$bucket/$key"
done < /tmp/components.tsv

echo "Artefacts published."
