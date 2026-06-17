# Control Service Pattern

> **Full documentation:** [docs/patterns/control-service.md](../../../docs/patterns/control-service.md): both modes, what each builds, inputs and outputs, and when to use it.

Creates a Control Service in one of two modes:

- `event_reactor`: EventBridge rule, listener queue, listener Lambda, micro event store, and trigger Lambda.
- `step_functions`: EventBridge rule that starts a Step Functions workflow with X-Ray tracing and CloudWatch logging.

Use `event_reactor` for collect/correlate/evaluate flows that are naturally event-stream based. Use `step_functions` for explicit orchestration, sagas, and workflows where visual state and managed retries are the right interface.
