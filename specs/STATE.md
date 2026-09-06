# STATE — read this first, every session

## Current phase: 0 — Specification — COMPLETE
## Last completed task: Phase 0 — specs/00-environment-spec.md written; scripts/validate.sh
##   reconciled with it (check 1 now includes `mail`; `application` documented as one-shot)
## Next task: run `/oro-discover` (Phase 1). Read-only. Haiku.
## Approved scope for this chunk: Phases 0 → 2, stopping at the Phase 2 approval gate.
##   Nothing state-changing. No Docker operations, no /etc/hosts, no stopping the Magento stack.
## Blocked on: nothing
## Open approvals needed: none yet
##   upcoming (Phase 3): scripts/magento-stack.sh stop, /etc/hosts entry (system file)
## Plan approved (Phase 2): NO — /oro-implement must refuse until this reads YES
## Validation table: 0/13 run
## UNVERIFIED items outstanding: 3 — see specs/00-environment-spec.md §10
##   (doc version banners; image tags/digests; ORO_INSTALL_OPTIONS contents)

## Facts on record — re-fetch anyway if you are about to write them down

CLAUDE.md's verification rule is **session-scoped**: a fact carried forward from a previous session
is not verified in this one. These are recorded to save re-deriving them, not to license citing
them unfetched. Cheap to re-confirm; do it before writing any of them into an artefact.

**OroCommerce 7.0 LTS is current.** March 2026 → March 2030 (2032 Extended). CE patch window ends
**March 2027**. Cadence: one LTS every March. Dev branch 7.1. Re-confirmed this session against
https://doc.oroinc.com/community/release-process/ — matches the target, no escalation needed.

**Platform**: PHP >= 8.5, PostgreSQL >= 17.6 (CE) / >= 18.3 (EE), Node >= 24.11.0 <25,
PNPM >= 10.7.0, Supervisor required. Redis >= 8.4 optional. Elasticsearch >= 9.2 and RabbitMQ >= 4.2
are **EE only**.

**docker-demo: 12 services**, verified this session from the upstream `compose.yaml`.
Long-running: `db php-fpm-app web ws consumer cron mail`.
One-shot, *expected* to show `Exited`: `volume-init web-init install restore` **and `application`**
— `application` runs `true` and depends on web+consumer+cron, so the dependency graph is what
starts the stack. Only `web` binds a host port (`published: 80`).

## Notes for whoever picks this up
- Nothing on the system has been changed. The Oro stack does not exist; `docker/` holds only
  `.env.template` and `.gitkeep`.
- The `docker_magento` stack is running (16 containers) and holds the RAM Oro needs. RAM is the
  binding constraint here, not ports. `scripts/preflight.sh` gives GO/NO-GO;
  `scripts/magento-stack.sh stop` is the lever and needs confirmation every time.
- Open discrepancy: `docs/oro-commerce-learning-plan.md` says PHP >= 8.4; the requirements page says
  >= 8.5. Not a blocker. Correcting the learning plan is Phase 6 work.
- Still untested: run `/oro-implement` while `Plan approved` reads NO. It must refuse and name the
  unmet gate.
