# STATE — read this first, every session

## Current phase: 5 — Evidence — **COMPLETE.** Next: Phase 6 — /oro-document
## Last completed task: **Phase 5 — evidence set captured, 10 artefacts (logs/phase5-*).**
##   Redaction verified: 37 credential-pattern matches, ALL [REDACTED], 0 leaks; URI sweep clean.
##   One prose hit reviewed, judged not a leak (default account name + placeholder email, no value).
##   D1 CONFIRMED FROM INSIDE: composer.lock -> oro/commerce, oro/platform, oro/customer-portal
##   all 6.1.6; no oro/commerce-enterprise package. CE proven at package level.
##   Digests captured (UNVERIFIED closed). Footprint corrected: **~3.22 GB across FOUR images** —
##   task 3.5's 2.67 GB missed oroinc/runtime:6.1-latest (553 MB), pulled later in 3.6.
##   Runtime observed: **PHP 8.4.14 · PostgreSQL 17.2 · Node ABSENT from the runtime image**
##   (assets built into the image, not compiled at runtime — the sharp Magento contrast).
##   Consumer: container elapsed 28:37 vs inner process 13:19 — job-runner.phar respawns on
##   --time-limit=15minutes. Process younger than its container is HEALTHY, not a crash.
##   NOTE: the command specified `php bin/console --version`; used the absolute path per T2.
## Decision D1: **ANSWERED 2026-09-06 — option A, build against 6.1.6 CE.**
##   specs/00-environment-spec.md §1 amended; CLAUDE.md verification rule amended (6.1 is now the
##   right doc page, 7.0 pages are forward references only).
## Next task: **Phase 6 — `/oro-document` (Opus).** Write docs/02-architecture.md from what was
##   OBSERVED, not what the docs claim. Material is in CHANGELOG Phase 4/5 entries + logs/phase5-*.
##   Check 7 remains open at user's discretion; it does not gate this phase.
## Approved scope: Phases 4 and 5 complete, read-only throughout. Phase 6 (docs) writes only to docs/.
## Blocked on: nothing.
## Open approvals needed: none outstanding. (Phase 3's two CONFIRM points were both granted and
##   are spent — no standing grant carries forward. Any future magento-stack start/stop, /etc/hosts
##   write, or docker/ bulk delete asks again.)
## Plan approved (Phase 2): **YES** — approved by the user 2026-09-06, after the G7 gate test.
##   Task-level STOP-AND-ASK approvals do NOT follow from this: 3.4 and 3.7 each ask again.
## Validation table: **13/13 run, 0 failures** — 9 PASS · 1 MANUAL (check 7, open by user choice) ·
##   3 EXPECTED-ABSENT. This IS the Phase 4 validation, not a per-task check.
## Plan tasks: **7/7 PASS** (Phase 3, complete) · Phase 4 validation complete, 0 failures
## UNVERIFIED items outstanding: **1** (was 4)
##   CLOSED: image digests — captured in Phase 5, all four sha256 recorded.
##   CLOSED: docker-demo master SHA — 202a279343e62ee99b8cc81f78c307a79958f80d confirmed at clone.
##   CLOSED: 6.1.6 runtime figures — read off the running containers: PHP 8.4.14, PG 17.2, no Node.
##   STILL OPEN: docs/01-environment-discovery.md §3.1 — Docker default address-pool upper bound.
##     Never tested; G9 did not bite during bring-up, so the bound remains unmeasured.

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

## Live system state as of 2026-09-06T18:44 — CHANGED from the "nothing has changed" era

- **OroCommerce 6.1.6 CE is RUNNING.** `http://oro.demo/` -> 200. Back office -> 302.
- 11/12 services; 7 long-running up: db php-fpm-app web ws consumer cron mail.
  `install` was never created — correct, it is `restore`'s alternative, not a peer.
- **`docker_magento` is STOPPED** (16 containers, `running: 0 total: 16`). The user's Magento
  environment is down. Restore with `scripts/magento-stack.sh start` — ask first, closed list.
- `/etc/hosts` has 11 lines, md5 `82732a5e72feb10194cd7bd09c610b39`, `127.0.0.1 oro.demo` at line 5.
  Pre-Oro md5 was `deb7c2f90acdc83235b4aecf8ae21a53`; the reverse sed is dry-run-proven to restore it.
- Images on disk: **~3.22 GB, four images** — application-init 1.25 GB, application 1.14 GB,
  runtime:6.1-latest 553 MB, pgsql:17.2-alpine 278 MB. Digests in logs/phase5-image-digests-*.
- Runtime: PHP 8.4.14 · PostgreSQL 17.2 · Symfony 6.4.28 · **no Node in the runtime image**.
- oro/commerce 6.1.6, oro/platform 6.1.6, oro/customer-portal 6.1.6; no EE package present.
- Consumers proven live: oro_message_queue drained 50 -> 11 -> 0 across three observations.
- **Console commands need the absolute path**: `/var/www/oro/bin/console`. WORKDIR is `/`.

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
