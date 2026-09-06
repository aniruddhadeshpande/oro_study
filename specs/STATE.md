# STATE — read this first, every session

## Current phase: 3 — Implementation — IN PROGRESS (1 of 7 tasks done)
## Last completed task: **3.1 — verify Docker and Compose v2. PASS.** server/client 28.3.3,
##   compose 2.39.1, user in `docker` group, `PREFLIGHT: GO` exit 0. RAM available 9331 MiB (need
##   5000) — wider margin than Phase 1's 6.8 GiB. Read-only; nothing changed.
##   logs/phase3-verify-docker-20260906T181235.log, logs/phase3-preflight-pre-20260906T181240.log
##   (G7 gate test PASSED before approval — plan task 0, closed, not repeatable.)
## Decision D1: **ANSWERED 2026-09-06 — option A, build against 6.1.6 CE.**
##   specs/00-environment-spec.md §1 amended; CLAUDE.md verification rule amended (6.1 is now the
##   right doc page, 7.0 pages are forward references only).
## Next task: **3.2 — clone oroinc/docker-demo into docker/, record the commit SHA.**
##   First state-changing task of the project. `docker/` is non-empty, so clone to a temp dir and
##   copy in; do NOT `git clone` directly into it. Run via `/oro-implement`.
## Approved scope: **Phase 3 approved** — tasks 3.1–3.7 may run, one per /oro-implement invocation.
## Blocked on: nothing.
## Open approvals needed:
##   Phase 3  — scripts/magento-stack.sh stop (task 3.4); /etc/hosts append (task 3.7);
##              bulk delete of docker/ contents (task 3.2 rollback only, if ever needed)
## Plan approved (Phase 2): **YES** — approved by the user 2026-09-06, after the G7 gate test.
##   Task-level STOP-AND-ASK approvals do NOT follow from this: 3.4 and 3.7 each ask again.
## Validation table: 0/13 run (validate.sh exits 2 — no compose file yet, correct)
## Plan tasks: 3.1 PASS · 3.2–3.7 pending
## UNVERIFIED items outstanding: 4
##   1 image digests behind tag 6.1.6 — tags known, digests recorded at pull time (Phase 3/5)
##   1 docs/01-environment-discovery.md §3.1 — Docker default address-pool upper bound
##   1 upstream docker-demo master SHA at clone time — 202a279... observed 2026-09-06, may move
##   1 6.1 system-requirements page never fetched — PHP/Node figures for 6.1.6 unconfirmed,
##     to be read off the running containers in Phase 4 (spec §1 note)

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
- G7 is **closed** — the gate test ran and passed; see "Last completed task" above. The refusal
  path is now the only part of the scaffolding proven to hold under a live invocation, and it can
  never be re-tested in this repo once the flag reads YES.
- **The target is 6.1.6, not 7.0.** A 6.1 doc page is the correct page. 7.0 material is a forward
  reference and must be labelled as such — see the amended verification rule in CLAUDE.md.
