#!/usr/bin/env sh
set -eu

ENDPOINT="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-west-2}"

cd "$(dirname "$0")/../../examples/subsystem-core/customer-subsystem"
terraform init -input=false
terraform apply -auto-approve

echo "--- asserting outputs are populated ---"
BUS_NAME="$(terraform output -raw event_bus_name)"
API_ENDPOINT="$(terraform output -raw bff_api_endpoint)"
TABLE_NAME="$(terraform output -raw customer_table_name)"

for value in "$BUS_NAME" "$API_ENDPOINT" "$TABLE_NAME"; do
  if [ -z "$value" ]; then
    echo "FAIL: expected a non-empty Terraform output" >&2
    exit 1
  fi
done

echo "--- asserting deployed resources exist and behave ---"
aws --endpoint-url "$ENDPOINT" events describe-event-bus --name "$BUS_NAME" >/dev/null \
  || { echo "FAIL: event bus $BUS_NAME not found" >&2; exit 1; }

TABLE_STATUS="$(aws --endpoint-url "$ENDPOINT" dynamodb describe-table --table-name "$TABLE_NAME" --query 'Table.TableStatus' --output text)"
if [ "$TABLE_STATUS" != "ACTIVE" ]; then
  echo "FAIL: table $TABLE_NAME status is $TABLE_STATUS, expected ACTIVE" >&2
  exit 1
fi

aws --endpoint-url "$ENDPOINT" dynamodb put-item \
  --table-name "$TABLE_NAME" \
  --item '{"pk": {"S": "smoke#1"}, "sk": {"S": "smoke"}}' >/dev/null \
  || { echo "FAIL: could not write to $TABLE_NAME" >&2; exit 1; }

GOT="$(aws --endpoint-url "$ENDPOINT" dynamodb get-item \
  --table-name "$TABLE_NAME" \
  --key '{"pk": {"S": "smoke#1"}, "sk": {"S": "smoke"}}' \
  --query 'Item.pk.S' --output text)"
if [ "$GOT" != "smoke#1" ]; then
  echo "FAIL: round-trip read from $TABLE_NAME returned '$GOT'" >&2
  exit 1
fi

aws --endpoint-url "$ENDPOINT" events put-events --entries \
  "[{\"EventBusName\": \"$BUS_NAME\", \"Source\": \"smoke.test\", \"DetailType\": \"SmokeTest\", \"Detail\": \"{}\"}]" \
  --query 'FailedEntryCount' --output text | grep -q '^0$' \
  || { echo "FAIL: PutEvents to $BUS_NAME was rejected" >&2; exit 1; }

echo "--- smoke assertions passed ---"
terraform output
