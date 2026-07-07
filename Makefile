.PHONY: fmt validate test runtime-test policy security smoke

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
	terraform test ./modules/patterns/frontend_edge
	terraform test ./modules/patterns/regional_health_check
	terraform test ./modules/patterns/fault_monitor
	terraform test ./modules/patterns/micro_frontend
	terraform test ./modules/patterns/identity
	terraform test ./modules/composition/subsystem
	terraform test ./modules/delivery/artefact_pipeline

runtime-test:
	cd runtime/nodejs && node --test
	cd examples/services/hello-service && node --test

policy:
	conftest test tests/fixtures/pass --policy policies/opa --all-namespaces
	! conftest test tests/fixtures/fail --policy policies/opa --all-namespaces

security:
	trivy config . --severity HIGH,CRITICAL --exit-code 1 --skip-dirs tests/fixtures

smoke:
	./tests/smoke/localstack-smoke.sh
