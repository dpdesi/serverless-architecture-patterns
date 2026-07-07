#!/usr/bin/env sh
set -eu

# The plugin cache keeps ~30 roots from each downloading the (large) AWS
# provider. Do NOT also point TMPDIR into the workspace: the provider's
# go-plugin handshake creates a unix socket under TMPDIR, and a deeply nested
# workspace path exceeds the ~104-character socket-path limit on Linux,
# failing every validate with "plugin failed to negotiate the handshake".
mkdir -p .terraform-plugin-cache
export TF_PLUGIN_CACHE_DIR="$PWD/.terraform-plugin-cache"

scan_dirs="examples stacks/reference"
if [ -d subsystems ]; then
  scan_dirs="$scan_dirs subsystems"
fi
roots=$(find $scan_dirs -name versions.tf -exec dirname {} \; | sort -u)

for root in $roots; do
  echo "==> validating $root"
  (cd "$root" && terraform init -backend=false -input=false && terraform validate)
done
