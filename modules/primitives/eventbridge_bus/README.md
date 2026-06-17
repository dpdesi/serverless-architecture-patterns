# EventBridge Bus Primitive

> **Full documentation:** [docs/patterns/primitives.md](../../../docs/patterns/primitives.md#eventbridge-bus): all four primitives, what each builds, inputs and outputs.

Creates a tagged custom EventBridge bus for autonomous subsystem routing. Custom buses are the default boundary for many-to-many event routing.

## Features

- Customer managed KMS key support.
- Optional bus resource policy.
- Optional archive for replay.
- Required `Environment`, `System`, and `Owner` tags.
