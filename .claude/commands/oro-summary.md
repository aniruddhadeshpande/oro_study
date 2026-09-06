---
description: Phase 7 — update the runbook and emit the final report
model: claude-opus-5
---
# Phase 7 — Architecture Summary

Update `runbook/oro-commerce-architecture-runbook.md` with what was **verified**. Everything in it
that this environment did not demonstrate gets an `UNVERIFIED:` prefix — most of the OroCloud, EE
messaging and HA sections will, and that is the honest outcome.

Emit the final report with exactly these sections:

```
Installation Status · Architecture Summary · Container Summary · Important Commands
Known Issues · Troubleshooting · Documentation Links · Architecture Diagram Links
Next HLD Topics · Next LLD Topics
```

- **Container Summary** is a table: name, image, role, ports, depends-on, impact if stopped.
- **Architecture Diagram Links** contains only URLs fetched successfully. Where Oro publishes none:
  *"No official architecture diagram found; conceptual diagram provided for learning."* pointing at
  `docs/`.
- **Known Issues** must be honest. Empty, on a first-time install, is not credible.
- **Next HLD/LLD Topics** must be specific to this environment's limits — e.g. RabbitMQ clustering
  is not demonstrable here because CE uses the DBAL transport; it needs the EE dev stack from the
  spec's secondary path.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
