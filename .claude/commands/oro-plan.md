---
description: Phase 2 — write the ordered implementation plan, then stop for approval
model: claude-opus-5
---
# Phase 2 — Plan

Write `specs/01-implementation-plan.md`: an ordered task list where every task has

| field | requirement |
|---|---|
| command | exact, runnable, wrapped in `scripts/capture.sh` if it changes state |
| validation | a command with an asserted expected result |
| rollback | mandatory — for `/etc/hosts`, capture the exact reverse `sed` *before* the edit |

Task order: verify Docker → clone `docker-demo` into `docker/` (record the commit SHA) →
`docker/.env` from template → `scripts/preflight.sh` → `scripts/magento-stack.sh stop` (confirm) →
`docker compose up restore` → `docker compose up application` → `/etc/hosts` entry (confirm).

**Then present the plan and stop.** No state-changing action until the user approves. Record the
approval in `specs/STATE.md`; `/oro-implement` refuses to run without it.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
