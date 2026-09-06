# Phase 1 — Environment Discovery

**Read-only.** Nothing on this host was changed. Every row below traces to a file in `logs/`,
captured through `scripts/capture.sh 1 <slug> -- <cmd>`. Timestamps are UTC, 2026-09-06.

The purpose of this phase is not to inventory the machine — it is to test the assumptions the
specification is built on *before* Phase 3 acts on them. Three of those assumptions turned out to
need restating, and one risk that the spec ranked low is the one that actually governs.

---

## 1. Findings

| # | Question | Observed | Evidence |
|---|---|---|---|
| 1 | Host OS / kernel | Linux Mint 22 (Wilma), `noble` base, kernel 6.8.0-79-generic, x86_64 | `phase1-os-kernel` |
| 2 | CPU | 4 cores | `phase1-resources` |
| 3 | RAM | 15 GiB total, **6.8 GiB available**, 8.7 GiB in use, 2.0 GiB swap unused | `phase1-resources` |
| 4 | Disk on `/` | 439 GiB total, 328 GiB free (22% used) | `phase1-resources` |
| 5 | Docker Engine | 28.3.3, storage driver `overlay2`, cgroup **v2** | `phase1-docker-versions` |
| 6 | Compose | v2.39.1 — plugin form, `docker compose` | `phase1-docker-versions` |
| 7 | Binary paths | `/usr/bin/docker`, `/usr/bin/git`, `/usr/bin/curl` | `phase1-tooling-paths` |
| 8 | git | 2.43.0 | `phase1-git-version` |
| 9 | Group membership | `aniruddha sudo users docker` — **in `docker`**, no `sudo` needed for the daemon | `phase1-user-groups` |
| 10 | Host port 80 | **not listening** — absent from `ss -lntp`, and `preflight.sh` reports `free` | `phase1-listening-ports`, `phase1-preflight` |
| 11 | Host ports held | 443, 8081, 9200, 15672 — all `0.0.0.0` + `[::]`, all `docker_magento` | `phase1-listening-ports` |
| 12 | Ports 5432 / 6379 | **not bound to the host** — Magento's MySQL and Redis are network-internal | `phase1-listening-ports` |
| 13 | `docker_magento` | 16 of 16 containers up, 2 hours uptime, 6 of them `(healthy)` | `phase1-magento-stack-status` |
| 14 | `oro.demo` resolution | **absent** — `getent hosts oro.demo` returns nothing | `phase1-name-resolution` |
| 15 | Existing `/etc/hosts` app entries | `127.0.0.1 php-docker.test`, `127.0.0.1 magento.docker` | `phase1-name-resolution` |
| 16 | Docker image store | 21 images, 6.9 GB, 2.7 GB reclaimable | `phase1-docker-storage-networks` |
| 17 | Docker bridge networks | 7 in use: 172.17–172.23, consecutive | `phase1-docker-storage-networks` |
| 18 | Preflight verdict | **GO** — every gate OK, `docker_magento` flagged `NOTE` | `phase1-preflight` |
| 19 | Docker address pool config | `/etc/docker/daemon.json` absent — stock defaults; pool not reported by `docker info` | `phase1-docker-address-pools` |

---

## 2. The three deltas from the spec's assumptions

The spec's Phase 3 was written against a generic host. Each of these was confirmed by running
something, not by repeating `CLAUDE.md`.

### 2.1 Docker is already present — Phase 3 task 1 is a verification, not an install

`docker --version` → 28.3.3. `docker compose version` → v2.39.1. `id -nG` puts the user in `docker`.
The daemon answers `docker info` without `sudo`, which is the part that actually matters: the whole
`/oro-*` workflow assumes unprivileged daemon access, and that is now demonstrated rather than
assumed.

Compose is the **v2 plugin**, so the `docker compose` form in `CLAUDE.md` is not a style preference
here — `docker-compose` (v1, hyphenated) is not installed at all and would fail outright.

**Consequence:** spec Phase 3 task 1 collapses to `scripts/preflight.sh` returning GO. No package
state changes, which keeps the entire implementation phase off the STOP-AND-ASK list except for the
two items already known (Magento stop, `/etc/hosts`).

### 2.2 No port collision — and the reason is narrower than "port 80 is free"

The Oro demo documentation warns to keep port 80 clear. That warning is satisfied here, but the
interesting result is the shape of what *is* bound:

```
0.0.0.0:443    0.0.0.0:8081    0.0.0.0:9200    0.0.0.0:15672     (+ [::] duplicates)
```

TLS proxy, phpMyAdmin, OpenSearch, RabbitMQ management. **5432 and 6379 do not appear** — Magento's
MySQL and Redis are reachable only on the compose network. That is what makes coexistence safe:
Oro's `db` (PostgreSQL) publishes no host port either, so the two data tiers cannot contend even in
principle. `web` at `published: 80` is Oro's *only* host binding, and port 80 is unclaimed.

Confirmed twice, independently: absent from the `ss -lntp` grep, and `preflight.sh` check 3 reports
`free`.

**Consequence:** no port remapping needed in `docker/.env`. `ORO_APP_DOMAIN=oro.demo` on :80 works
as documented.

### 2.3 RAM is the binding constraint — stated here, before Phase 3

This is the finding that changes how Phase 3 must be sequenced.

| | |
|---|---|
| Total | 15 GiB (`docker info` MemTotal 16,650,260,480 B = 15.5 GiB) |
| Used now | 8.7 GiB — 16 Magento containers plus the desktop |
| **Available** | **6.8 GiB** (`preflight.sh`, seconds later: 7020 MiB) |
| Swap | 2.0 GiB, **0 B used** |
| Oro peak estimate | ~5 GiB during install / reindex |

Headroom is therefore **~1.8 GiB** with Magento running — and the peak is an estimate, not a
measurement. Swap offers 2 GiB of cover, but a PHP install process that starts swapping does not
fail cleanly; it stalls, and on a 4-core box it stalls for a long time. The `preflight.sh` GO
verdict is against a 5000 MiB threshold and is honest, but GO with 1.8 GiB of margin is a different
proposition from GO with 8 GiB.

Note also that `df -h /` shows 328 GiB free, and the disk gate wants 20 GiB. **Disk is not a
constraint and will not become one.** Every resource risk in this build is a memory risk.

**Consequence for Phase 2:** `magento-stack.sh stop` should be planned as the *normal* path before
the first Oro bring-up, not as a contingency triggered by a NO-GO. It is reversible
(`magento-stack.sh start`), it costs nothing but a restart, and it converts 1.8 GiB of margin into
roughly 8 GiB. It still requires explicit confirmation each time — no standing grant.

---

## 3. Additional findings not anticipated by the spec

### 3.1 Docker network address allocation — checked, not fully closed

Seven bridge networks occupy 172.17.0.0/16 through 172.23.0.0/16, consecutively:

```
bridge 172.17  ·  docker_magento_backend 172.18  ·  docker_magento_frontend 172.19
docker_php_backend 172.20  ·  magento_default 172.21  ·  root_default 172.22
docker_magento_learning_network 172.23
```

`/etc/docker/daemon.json` is **absent**, so the daemon is running stock defaults, and `docker info`
does not report the address pool on this version — checked, `phase1-docker-address-pools`. The
allocation is therefore visibly sequential from 172.17 upward, and Oro's compose file will create
one more network, but:

`UNVERIFIED:` **the upper bound of the default address pool.** The number of /16 slots remaining is
not determinable from anything runnable on this host without creating a network, which Phase 1 may
not do. Pool exhaustion is a real failure mode on a machine carrying this many stacks, and it
surfaces as `could not find an available, non-overlapping IPv4 address pool` at `up` time — not at
`config` time, which makes it easy to misdiagnose as a compose-file problem.

Treated as low risk (the observed range is nowhere near the top of RFC 1918 space) but it is the
error to recognise if the first `docker compose up` fails on networking rather than on memory.

Worth recording separately: three of those seven networks (`docker_php_backend`, `magento_default`,
`root_default`) belong to no running container — residue from earlier stacks. They are **not** to be
removed; `docker network rm` is adjacent to the STOP-AND-ASK list, and the reclaim is not worth the
risk unless exhaustion is actually proven.

### 3.2 `/etc/hosts` already carries the same pattern Oro needs

```
127.0.0.1  php-docker.test
127.0.0.1  magento.docker
```

`oro.demo` is absent, confirmed by `getent hosts` (which exercises the real NSS path, not just a
`grep` of the file). So the Phase 3 edit is a single append in an established idiom, and the
rollback is a line deletion. The `before` copy of the file must still be captured prior to the edit
— it is a system file on the closed list.

### 3.3 Reclaimable Docker storage exists but is off-limits

2.708 GB of images (39%) and 1.193 GB of build cache are reclaimable, plus 673.9 MB across 22
inactive volumes. `docker system prune` in any form is on the STOP-AND-ASK list, and with 328 GiB
free there is no reason to raise it. Recorded so that a future disk-pressure conversation starts
from a measurement.

### 3.4 cgroup v2 and overlay2

Both are what Oro's images expect. cgroup v2 matters specifically because container memory limits
and OOM behaviour are enforced through it — relevant given §2.3. No action.

---

## 4. Gap list

Explicit, and each one names where it closes.

| # | Gap | Why it is still open | Closes at |
|---|---|---|---|
| G1 | Oro image tags and digests unknown — `ORO_IMAGE`, `ORO_IMAGE_TAG`, `ORO_BASELINE_VERSION`, `ORO_PG_VER` | The repository is not cloned; `docker/` holds only `.env.template` and `.gitkeep`. Upstream defaults live in the repo's own `.env` | Phase 3, task 3.2 |
| G2 | `ORO_INSTALL_OPTIONS` contents unknown | Same — passed by the `install` service, value not yet read | Phase 3, task 3.2 |
| G3 | Doc page version banners not confirmed as the 7.0 view | Content was fetched and used, but the extract did not restate the banner. Inference from figures (PHP 8.5 / PG 17.6), not confirmation | Next fetch of either page — Phase 3 or Phase 6 |
| G4 | Actual Oro memory footprint unmeasured | ~5 GiB is an estimate. The real number comes from `docker stats` during install and reindex | Phase 4, and it is the number Phase 7 should report |
| G5 | Whether `restore` alone yields a *working* app | A restored database and a passing container are not the same claim. `validate.sh` checks 5–10 are the test | Phase 4 |
| G6 | `docker compose config` output never redacted against real credentials | `capture.sh` redaction is proven against a synthetic self-test only. The first real credential-bearing output does not exist until the stack does | Phase 3, first `compose config` capture |
| G7 | `/oro-implement` gate has never been exercised | The refusal path — `Plan approved (Phase 2): NO` — is scaffolding that has never actually run | Before Phase 3, deliberately |
| G8 | Learning plan states PHP >= 8.4; requirements page states >= 8.5 | Documented in `specs/00-environment-spec.md` §9. Not a blocker — no PHP is installed on the host, it is all in-container | Phase 6 |
| G9 | Docker default address-pool upper bound unknown — see §3.1 | Not determinable without creating a network, which is out of scope for a read-only phase | Phase 3, first `compose up` — or never, if it does not bite |

---

## 5. Verdict

The environment is **ready for Phase 2 planning**. `preflight.sh` returns GO, every tool the spec
requires is present at or above the version it assumes, and the two risks the spec ranked highest —
missing Docker, port collision — are both disproved.

The one risk that stands is memory, and it has a named, reversible lever. That lever belongs in the
plan as a step, not as an exception handler.

Nothing on this host was modified during Phase 1.
