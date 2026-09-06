# STATE — read this first, every session

## Current phase: 1 — Discovery — COMPLETE
## Last completed task: Phase 1 — docs/01-environment-discovery.md written from 12 captured
##   logs. All three spec assumptions tested; 9 gaps registered (G1–G9), each with a closing phase.
## Next task: run `/oro-plan` (Phase 2). Writes specs/01-implementation-plan.md, then STOPS for
##   approval. Opus. Still nothing state-changing.
## Approved scope for this chunk: Phases 0 → 2, stopping at the Phase 2 approval gate.
##   Nothing state-changing. No Docker operations, no /etc/hosts, no stopping the Magento stack.
## Blocked on: nothing
## Open approvals needed: none yet
##   upcoming (Phase 3): scripts/magento-stack.sh stop, /etc/hosts entry (system file)
## Plan approved (Phase 2): NO — /oro-implement must refuse until this reads YES
## Validation table: 0/13 run (validate.sh exits 2 — no compose file yet, correct)
## UNVERIFIED items outstanding: 4
##   3 in specs/00-environment-spec.md §10 (doc version banners; image tags/digests;
##     ORO_INSTALL_OPTIONS contents)
##   1 in docs/01-environment-discovery.md §3.1 (Docker default address-pool upper bound)

## Facts on record — re-fetch anyway if you are about to write them down

CLAUDE.md's verification rule is **session-scoped**: a fact carried forward from a previous session
is not verified in this one. These are recorded to save re-deriving them, not to license citing
them unfetched. Cheap to re-confirm; do it before writing any of them into an artefact.

**OroCommerce 7.0 LTS is current.** March 2026 → March 2030 (2032 Extended). CE patch window ends
**March 2027**. Cadence: one LTS every March. Dev branch 7.1. Confirmed 2026-09-06 against
https://doc.oroinc.com/community/release-process/ — matches the target, no escalation needed.

**Platform**: PHP >= 8.5, PostgreSQL >= 17.6 (CE) / >= 18.3 (EE), Node >= 24.11.0 <25,
PNPM >= 10.7.0, Supervisor required. Redis >= 8.4 optional. Elasticsearch >= 9.2 and RabbitMQ >= 4.2
are **EE only**.

**docker-demo: 12 services**, from the upstream `compose.yaml`.
Long-running: `db php-fpm-app web ws consumer cron mail`.
One-shot, *expected* to show `Exited`: `volume-init web-init install restore` **and `application`**
— `application` runs `true` and depends on web+consumer+cron, so the dependency graph is what
starts the stack. Only `web` binds a host port (`published: 80`).

**Host, measured in Phase 1** (logs/phase1-*, 2026-09-06):
Linux Mint 22 / kernel 6.8.0-79 · 4 CPU · 15 GiB RAM, **6.8 GiB available** · 328 GiB free on `/`
Docker 28.3.3 (overlay2, cgroup v2) · Compose v2.39.1 · git 2.43.0 · user in `docker` group
Port 80 free. 443/8081/9200/15672 held by docker_magento. 5432/6379 NOT host-bound.
`oro.demo` does not resolve. 7 bridge networks, 172.17–172.23.

## Notes for whoever picks this up

- **Nothing on the system has been changed** through the end of Phase 1. The Oro stack does not
  exist; `docker/` holds only `.env.template` and `.gitkeep`.
- The single governing risk is **memory**, not ports and not disk. ~1.8 GiB of headroom above Oro's
  estimated ~5 GiB peak while Magento runs. Plan `magento-stack.sh stop` as the normal path in
  Phase 3, not as a contingency — it needs confirmation every time regardless.
- Do **not** prune networks, images, volumes or build cache to reclaim anything. 328 GiB free means
  there is no argument for it, and it is on the closed list.
- Open discrepancy: `docs/oro-commerce-learning-plan.md` says PHP >= 8.4; the requirements page says
  >= 8.5. Not a blocker — no PHP on the host. Correcting the learning plan is Phase 6 work (G8).
- Still untested (G7): run `/oro-implement` while `Plan approved` reads NO. It must refuse and name
  the unmet gate. Cheapest place to do this is immediately after Phase 2 is written.
- Redaction (G6) is proven only against a synthetic self-test. The first real test is the first
  `docker compose config` capture in Phase 3.
