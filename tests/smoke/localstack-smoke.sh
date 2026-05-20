#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/../../examples/subsystem-core/customer-subsystem"
terraform init -input=false
terraform apply -auto-approve
terraform output
