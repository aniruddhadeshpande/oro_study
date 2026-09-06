---
description: Phase 5 — capture the evidence set to logs/, redacted
model: claude-haiku-4-5-20251001
---
# Phase 5 — Evidence Collection

Each through `scripts/capture.sh 5 <slug> -- <cmd>`, from `docker/`:

- `docker compose ps`
- `docker compose config --services`
- `docker compose images` and the image digests
- `docker compose exec -T php-fpm-app php bin/console --version`
- the running consumer processes
- the Phase 4 validation TSV, copied forward

Then confirm the redaction held:
`grep -rniE '(password|secret|token|api[_-]?key)[[:space:]]*[=:][[:space:]]*[^[:space:]]' logs/ --exclude-dir=raw`
must return nothing but `[REDACTED]` matches. If a value leaks, remove the artefact and fix
`scripts/capture.sh` before continuing.

Evidence is a deliverable, not a by-product — it is what makes this environment defensible in review.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
