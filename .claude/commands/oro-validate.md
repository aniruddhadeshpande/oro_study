---
description: Phase 4 — run the 13-check validation table and record pass/fail per check
model: claude-sonnet-5
---
# Phase 4 — Validation

Run `scripts/capture.sh 4 validation-table -- scripts/validate.sh`.

Report the table as returned. Rules:
- No narrative claims. Every line is a check, a command, and an asserted result.
- Checks 11–13 resolving to `EXPECTED-ABSENT` is the **correct** CE outcome — Redis config,
  RabbitMQ and Elasticsearch are Enterprise Edition. Record it as an architectural finding for
  `docs/02-architecture.md`, not as a failure.
- Check 6 failing means the install is **broken**, not partial. Say so.
- Check 7 is deliberately manual: create a product in `/admin`, time its appearance on the
  storefront, record the bound. Then repeat it with the consumer stopped and confirm it does *not*
  appear — that single experiment is the async path, proven.

Any FAIL blocks Phase 6. Fix and re-run rather than documenting a system you have not validated.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
