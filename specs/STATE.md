# STATE — read this first, every session

## Current phase: 2 — Plan — COMPLETE, awaiting approval
## Last completed task: Phase 2 — specs/01-implementation-plan.md written. Task 0 + tasks 3.1–3.7,
##   each with command / validation / rollback. docs/troubleshooting.md created (entry T1).
## Next task: **user decision D1, then plan approval.** Nothing else runs first.
##   After both: `/oro-implement` (Phase 3, Sonnet). Task 0 of that phase is the G7 gate test,
##   which must be run BEFORE the approval flag is flipped.
## Approved scope for this chunk: Phases 0 → 2. **Reached.** Phase 3 needs fresh approval.
## Blocked on: **Decision D1 — the target version.** See specs/01-implementation-plan.md §0.
##   The official Docker demo cannot deliver 7.0 CE; it delivers 6.1.6. Recommendation: accept 6.1.6
##   (option A) and amend specs/00-environment-spec.md §1. Nothing state-changing until D1 is made.
## Open approvals needed:
##   now      — D1 (version target), then `Plan approved (Phase 2)` below
##   Phase 3  — scripts/magento-stack.sh stop (task 3.4); /etc/hosts append (task 3.7);
##              bulk delete of docker/ contents (task 3.2 rollback only, if ever needed)
## Plan approved (Phase 2): NO — /oro-implement must refuse until this reads YES
## Validation table: 0/13 run (validate.sh exits 2 — no compose file yet, correct)
## UNVERIFIED items outstanding: 3
##   1 image digests behind tag 6.1.6 — tags now known, digests recorded at pull time (Phase 3/5)
##   1 docs/01-environment-discovery.md §3.1 — Docker default address-pool upper bound
##   1 upstream docker-demo master SHA at clone time — 202a279... observed 2026-09-06, may move

## The Phase 2 finding, in one paragraph

`oroinc/docker-demo` has no `7.0` branch and no tags; its `master` pins `ORO_IMAGE_TAG=6.1.6`.
Docker Hub `oroinc/orocommerce-application` has five tags, newest **6.1.6 pushed 2025-12-18**, and
the whole `orocommerce-application*` family last moved that day — **no 7.0 CE image exists.** The
7.0 documentation page (banner confirmed **7.0 (latest)**) nonetheless instructs a bare
`git clone` of that repo. So Oro ships 7.0 docs over a 6.1 demo. Overriding `ORO_IMAGE_TAG=7.0.x`
would reference an image that is not published. Evidence: `logs/phase2-remote-refs`,
`-upstream-env`, `-dockerhub-tags`, `-runtime-tags`, `-oroinc-namespace`, `-demo-docker-page`,
`-release-process-recheck`.

## Facts on record — re-fetch anyway if you are about to write them down

CLAUDE.md's verification rule is **session-scoped**: a fact carried forward from a previous session
is not verified in this one. These are recorded to save re-deriving them, not to license citing
them unfetched.

**Release lines, re-confirmed 2026-09-06** against doc.oroinc.com/community/release-process/
(banner: 7.0 (latest)). 7.0 LTS March 2026 → March 2030 (2032 Extended). **CE patch windows:
7.0 = March 2026 → March 2027 (active); 6.1 = March 2025 → March 2026 (expired).** One LTS each
March. Accepting 6.1.6 means accepting an expired CE patch line — acceptable for a local HTTP-only
learning box, and stated rather than glossed.

**Upstream defaults, read from docker-demo master `.env` 2026-09-06** (`phase2-upstream-env`):
`ORO_IMAGE=oroinc/orocommerce-application` · `ORO_IMAGE_TAG=6.1.6` · `ORO_BASELINE_VERSION=6.1-latest`
`ORO_DB_VERSION=17.2` / `ORO_PG_VER=17.2-alpine` · `ORO_APP_DOMAIN=oro.demo` · `ORO_ENV=prod`
`ORO_INSTALL_OPTIONS=` (**empty**) · `ORO_SAMPLE_DATA=y` · `HP_MEMORY_LIMIT=6096M`
CE architecture, confirmed in the file itself: `ORO_MQ_DSN=dbal:`,
`ORO_SEARCH_ENGINE_DSN=orm:?prefix=oro_search`, `ORO_MAILER_DSN=smtp://mail:1025`.
Credential values are in that file; they are redacted in the log and are not repeated anywhere.

**docker-demo: 12 services.** Long-running: `db php-fpm-app web ws consumer cron mail`.
One-shot, *expected* `Exited`: `volume-init web-init install restore` **and `application`** —
`application` runs `true` and depends on web+consumer+cron, so the dependency graph starts the
stack. Only `web` binds a host port (`published: 80`).

**Host, measured in Phase 1** (logs/phase1-*, 2026-09-06):
Linux Mint 22 / kernel 6.8.0-79 · 4 CPU · 15 GiB RAM, **6.8 GiB available** · 328 GiB free on `/`
Docker 28.3.3 (overlay2, cgroup v2) · Compose v2.39.1 · git 2.43.0 · user in `docker` group
Port 80 free. 443/8081/9200/15672 held by docker_magento. 5432/6379 NOT host-bound.
`oro.demo` does not resolve. 7 bridge networks, 172.17–172.23.

**`/etc/hosts` pre-state, measured 2026-09-06** — the rollback asserts against this:
10 lines · md5 `deb7c2f90acdc83235b4aecf8ae21a53` · 0 occurrences of `oro.demo` ·
lines 3–4 already `127.0.0.1 php-docker.test` and `127.0.0.1 magento.docker`.

## Notes for whoever picks this up

- **Nothing on the system has been changed** through the end of Phase 2. The Oro stack does not
  exist; `docker/` holds only `.env.template` and `.gitkeep`; `/etc/hosts` is untouched; the 16
  `docker_magento` containers are still running.
- **Do not copy `.env.template` over `docker/.env`.** Upstream ships a complete `.env` and compose
  depends on all of it; overwriting strips the image tags, DB credentials and nginx upstream JSON
  and breaks the stack in a way that looks like an Oro bug. G12, plan task 3.3.
- The governing risk is still **memory**, not ports and not disk. `magento-stack.sh stop` is a
  planned step in Phase 3, not a contingency — and it needs confirmation every time regardless.
- Do **not** prune networks, images, volumes or build cache. 328 GiB free, and it is on the
  closed list.
- **`capture.sh` redaction does not catch prose credentials** — proven live, see
  `docs/troubleshooting.md` T1 and G11. Machine output can be trusted to the filter; a captured
  documentation page must be read before it is committed.
- G6 is **closed**: redaction now proven against real credential-bearing output, not a self-test.
- G7 is still untested and is task 0 of the implementation plan — run `/oro-implement` while this
  file reads `Plan approved (Phase 2): NO` and confirm it refuses and names the gate.
