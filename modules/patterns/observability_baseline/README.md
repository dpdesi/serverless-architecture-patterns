# Observability Baseline Pattern

> **Full documentation:** [docs/patterns/observability-baseline.md](../../../docs/patterns/observability-baseline.md): the alarms it creates, the alert topic, inputs and outputs, and when to use it.

Creates the shared observability baseline for autonomous services:

- Alarm SNS topic with KMS encryption.
- Lambda error, throttle, and duration alarms.
- Optional DLQ depth alarms.
- Optional CloudWatch dashboard.
- Standard ADOT and Powertools environment variable outputs for callers to merge into Lambda modules.

Lambda functions still need an ADOT layer or collector configuration supplied by the consuming service; this module provides the shared settings and monitoring surface.
