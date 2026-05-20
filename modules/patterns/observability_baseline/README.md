# Observability Baseline Pattern

Creates the shared observability baseline for autonomous services:

- Alarm SNS topic with KMS encryption.
- Lambda error, throttle, and duration alarms.
- Optional DLQ depth alarms.
- Optional CloudWatch dashboard.
- Standard ADOT and Powertools environment variable outputs for callers to merge into Lambda modules.

Lambda functions still need an ADOT layer or collector configuration supplied by the consuming service; this module provides the shared settings and monitoring surface.
