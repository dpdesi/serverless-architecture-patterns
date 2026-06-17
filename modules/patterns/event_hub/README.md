# Event Hub Pattern

> **Full documentation:** [docs/patterns/event-hub.md](../../../docs/patterns/event-hub.md): what it builds, how it works, inputs and outputs, and when to use it.

Creates the event hub at the centre of an autonomous subsystem. It uses a custom EventBridge bus for many-to-many routing, target dead-letter queues, optional archives, and optional EventBridge Pipes for point-to-point movement where a full bus route would add little value.

This pattern supports the book's event-first topology guidance: connect services through an event hub and keep services coupled to events rather than direct calls.
