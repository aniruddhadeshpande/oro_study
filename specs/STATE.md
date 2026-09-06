# STATE — read this first, every session

## Current phase: 0 — Specification (not started)
## Last completed task: setup — scaffolding built and self-tested (see CHANGELOG 2026-09-06)
## Next task: run `/oro-spec` to write specs/00-environment-spec.md
## Blocked on: nothing
## Open approvals needed: none yet
##   upcoming: scripts/magento-stack.sh stop (Phase 3), /etc/hosts entry (Phase 3, system file)
## Plan approved (Phase 2): NO — /oro-implement must refuse until this reads YES
## Validation table: 0/13 run
## UNVERIFIED items outstanding: none

## Notes for whoever picks this up
- Nothing on the system has been changed yet. The Oro stack does not exist; `docker/` is empty.
- The `docker_magento` stack is running and holds the RAM Oro needs. `scripts/preflight.sh` says
  GO or NO-GO; `scripts/magento-stack.sh stop` is the lever, and it needs confirmation each time.
- Model routing and the compact-at-phase-boundary rule are in CLAUDE.md.
