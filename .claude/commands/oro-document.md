---
description: Phase 6 — write the architecture docs from what was observed
model: claude-opus-5
---
# Phase 6 — Documentation

Refuse to start while any Phase 4 check is unrun or FAILing.

Write from the evidence in `logs/`, not from what the docs claim. Where the two disagree, that
disagreement is the most interesting thing on the page — say so.

- **`docs/02-architecture.md`** — container inventory (role, ports, depends-on, failure impact per
  container), a derived Mermaid topology, the request path, the async path, and where cache, search,
  queue and cron actually sit in *this* stack.
- **`docs/03-request-flow.md`** — one synchronous storefront trace and one asynchronous trace,
  annotated with the container at every hop.
- **`docs/troubleshooting.md`** — only failures actually hit, with root cause and fix. If nothing
  failed, write that sentence. Hypothetical problems are worse than an empty page.
- **`docs/04-magento-mapping.md`** — observed components mapped to Magento, marked
  `same`/`similar`/`different`/`no equivalent`. Do not force an equivalence; "no equivalent" is a
  valid and useful answer (ownership tree, layout engine, API processor chain, Operations/Workflows).

Every doc URL must have been fetched this session or carry `UNVERIFIED:`.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
