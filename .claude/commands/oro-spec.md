---
description: Phase 0 — write the environment specification before anything touches the system
model: claude-opus-5
---
# Phase 0 — Specification

Write `specs/00-environment-spec.md`. Nothing on the system may change until this file exists.

Contents:
- **Target**: OroCommerce 7.0 LTS Community Edition. Confirm the current LTS against
  https://doc.oroinc.com/community/release-process/ by fetching it. If the LTS has moved on, report
  the discrepancy and ask before continuing.
- **Chosen install path and why**: the official Docker demo
  (https://doc.oroinc.com/backend/setup/demo-environment/docker/), `restore` first for a fast path
  to a working system, then a second checkout with `install` to observe the lifecycle.
- **Expected components** when done, each with an acceptance criterion that is a command with an
  asserted result — not a feeling.
- **Out of scope**, explicitly: no TLS, no production hardening, no EE components, no multi-node,
  no changes to the co-resident `docker_magento` stack beyond stop/start.

Anything you could not fetch or execute gets an `UNVERIFIED:` prefix.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
