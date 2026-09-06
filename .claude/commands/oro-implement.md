---
description: Phase 3 — execute exactly one plan task, validate it, record it
argument-hint: [task number, e.g. 3.5]
model: claude-sonnet-5
---
# Phase 3 — Implementation (one task per invocation)

Refuse to run if `specs/STATE.md` does not record an approved Phase 2 plan.

Execute **one** task — $1 if given, otherwise the "Next task" in `STATE.md`. Never batch.

1. Announce the task, its validation check, and its rollback.
2. If it appears on the STOP-AND-ASK list in `CLAUDE.md`, ask now and wait.
3. Run it through `scripts/capture.sh 3 <slug> -- <cmd>`.
4. Run its validation check and state the result plainly.
5. Append to `CHANGELOG.md`; update `STATE.md`.

**On failure:** stop. Diagnose the root cause — do not retry blindly. If the task fails twice, stop
and hand the diagnosis to Opus (`/model opus`) rather than burning retries. Record both the failure
and the fix in `docs/troubleshooting.md`, then re-validate.

Long output (install, reindex) stays in `logs/` and is read back with `grep`. Do not paste it.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
