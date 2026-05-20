.PHONY: fmt validate test policy security smoke

fmt:
	terraform fmt -check -recursive

validate:
	./scripts/validate.sh

test:
	terraform test ./modules/primitives/lambda_function
	terraform test ./modules/primitives/api_http
	terraform test ./modules/primitives/dynamodb_table
	terraform test ./modules/primitives/eventbridge_bus
	terraform test ./modules/patterns/observability_baseline
	terraform test ./modules/patterns/event_hub
	terraform test ./modules/patterns/bff_service
	terraform test ./modules/patterns/esg_service
	terraform test ./modules/patterns/control_service
	terraform test ./modules/patterns/event_lake

policy:
	conftest test tests/fixtures/pass --policy policies/opa
	! conftest test tests/fixtures/fail --policy policies/opa

security:
	trivy config .

smoke:
	./tests/smoke/localstack-smoke.sh
