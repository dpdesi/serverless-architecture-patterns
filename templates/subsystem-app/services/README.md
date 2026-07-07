# services/

The Lambda source for this subsystem's components. **Co-location is the default**: the deploy workflow builds each component here and publishes the zip to the key the composer expects.

The infrastructure expects the code inside each component to honour the library's
[runtime contract](https://github.com/dpdesi/serverless-architecture-patterns/blob/main/docs/runtime-contract.md):
the event envelope shape, `ReportBatchItemFailures` semantics, and fault events for poison
messages. A zero-dependency Node.js reference implementation (`@atrium/service-runtime`) and a
worked `hello-service` live in the library repository — vendor the runtime package into this repo
(e.g. `vendor/service-runtime`) and depend on it per component with a `file:` dependency, or
implement the contract directly in the runtime of your choice.

## Layout

One directory per component, named to match the manifest:

```
services/
  <bff-name>/
    rest/        # synchronous HTTP API handler
    listener/    # consumes hub events into the table (CQRS)
    trigger/     # publishes table changes as events
  <control-name>/      # event_reactor mode only
    listener/
    trigger/
  <esg-name>/
    ingress/     # normalises inbound webhooks into events
    egress/      # delivers outbound events to the external system
```

A component is built if `services/<service>/<component>/` exists. If it has a `package.json`, the build runs `npm ci` first; otherwise it just zips the directory. Bring any runtime — the build zips what it finds.

## The escape hatch: externally-published artefacts

If a component is built and versioned by its own service repo (different team, independent cadence), don't put its source here. Instead give that component an explicit `artefacts:` block in `subsystem.yaml` pointing at its published bucket/key:

```yaml
controls:
  - name: pricing-engine
    mode: event_reactor
    subscribes: [PriceRequested]
    artefacts:
      listener: { bucket: pricing-artefacts, key: pricing/listener/1.4.2.zip }
      trigger:  { bucket: pricing-artefacts, key: pricing/trigger/1.4.2.zip }
```

The build step sees the override and skips it; Terraform references the external location directly. Co-located and external components can coexist in one subsystem — decide per component by who owns the code, not by changing the tooling.
