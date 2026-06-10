variable "manifest" {
  description = "Subsystem manifest, typically yamldecode(file(\"subsystem.yaml\")). Validated against schema/subsystem.schema.json in CI; the validations below enforce the structural essentials at plan time."
  type        = any

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}$", var.manifest.subsystem))
    error_message = "manifest.subsystem must match ^[a-z][a-z0-9-]{1,23}$ (it prefixes every resource name)."
  }

  validation {
    condition = alltrue([
      contains(keys(try(var.manifest.tags, {})), "Environment"),
      contains(keys(try(var.manifest.tags, {})), "System"),
      contains(keys(try(var.manifest.tags, {})), "Owner"),
    ])
    error_message = "manifest.tags must include Environment, System, and Owner."
  }

  validation {
    condition = alltrue([
      for b in try(var.manifest.bffs, []) : can(regex("^[a-z][a-z0-9-]{1,23}$", b.name))
    ])
    error_message = "Every manifest.bffs[*].name must match ^[a-z][a-z0-9-]{1,23}$."
  }

  validation {
    condition = alltrue([
      for c in try(var.manifest.controls, []) : can(regex("^[a-z][a-z0-9-]{1,23}$", c.name)) && contains(["event_reactor", "step_functions"], c.mode) && length(try(c.subscribes, [])) > 0
    ])
    error_message = "Every manifest.controls[*] needs a valid name, mode of event_reactor or step_functions, and a non-empty subscribes list."
  }

  validation {
    condition = alltrue([
      for e in try(var.manifest.esgs, []) : can(regex("^[a-z][a-z0-9-]{1,23}$", e.name)) && length(try(e.egress, [])) > 0
    ])
    error_message = "Every manifest.esgs[*] needs a valid name and a non-empty egress list."
  }

  validation {
    condition = length(distinct(concat(
      [for b in try(var.manifest.bffs, []) : b.name],
      [for c in try(var.manifest.controls, []) : c.name],
      [for e in try(var.manifest.esgs, []) : e.name],
      ))) == length(concat(
      [for b in try(var.manifest.bffs, []) : b.name],
      [for c in try(var.manifest.controls, []) : c.name],
      [for e in try(var.manifest.esgs, []) : e.name],
    ))
    error_message = "Service names must be unique across bffs, controls and esgs - they share the subsystem name prefix."
  }

  validation {
    condition     = !try(var.manifest.operations.regional_health.enabled, false) || length(try(var.manifest.bffs, [])) > 0
    error_message = "operations.regional_health requires at least one BFF - its health alarms are derived from BFF functions and tables."
  }

  validation {
    condition = can(var.manifest.artefact_defaults.bucket) || alltrue(concat(
      [for b in try(var.manifest.bffs, []) : can(b.artefacts.rest.bucket) && can(b.artefacts.listener.bucket) && can(b.artefacts.trigger.bucket)],
      [for c in try(var.manifest.controls, []) : c.mode != "event_reactor" || (can(c.artefacts.listener.bucket) && can(c.artefacts.trigger.bucket))],
      [for e in try(var.manifest.esgs, []) : can(e.artefacts.ingress.bucket) && can(e.artefacts.egress.bucket)],
    ))
    error_message = "Provide manifest.artefact_defaults.bucket, or explicit artefacts for every BFF (rest/listener/trigger), every event_reactor control (listener/trigger) and every ESG (ingress/egress)."
  }
}
