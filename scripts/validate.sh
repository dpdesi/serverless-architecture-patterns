#!/usr/bin/env sh
set -eu

mkdir -p .terraform-tmp .terraform-plugin-cache
export TMPDIR="$PWD/.terraform-tmp"
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
