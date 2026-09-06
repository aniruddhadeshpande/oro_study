# 01 — Implementation Plan (Phase 3)

Gate: `specs/STATE.md` read at Phase 1 — COMPLETE. `CLAUDE.md` read. Nothing state-changing has run.

Every task below carries a **command**, a **validation** with an asserted result, and a **rollback**.
Tasks that change state run through `scripts/capture.sh` so the evidence is a by-product, not a
chore. Tasks marked **CONFIRM** stop and ask, every time, with no standing grant.

---

## 0. Blocking decision — the target version cannot be met by the chosen path

This is the finding of Phase 2, and it invalidates part of `specs/00-environment-spec.md` §1.

**Measured this session, read-only:**

| Evidence | Result | Log |
|---|---|---|
| `git ls-remote --heads --tags oroinc/docker-demo` | branches `5.0 5.1 6.0 master`. **No `7.0` branch. No tags at all.** | `phase2-remote-refs` |
| `master:.env` | `ORO_IMAGE_TAG=6.1.6`, `ORO_BASELINE_VERSION=6.1-latest`, `ORO_DB_VERSION=17.2` | `phase2-upstream-env` |
| Docker Hub `oroinc/orocommerce-application` tags | 5 total; newest **6.1.6**, pushed **2025-12-18**. No 7.0 tag | `phase2-dockerhub-tags` |
| Docker Hub `oroinc/runtime` tags | 6 total; newest **6.1-latest**, pushed 2025-12-17 | `phase2-runtime-tags` |
| Docker Hub `oroinc/` namespace, 46 repos, newest first | whole `orocommerce-application*` family last pushed 2025-12-18 | `phase2-oroinc-namespace` |
| `doc.oroinc.com/backend/setup/demo-environment/docker/` | version banner reads **7.0 (latest)**; instruction is `git clone https://github.com/oroinc/docker-demo.git` with **no branch or tag** — i.e. `master` | `phase2-demo-docker-page` |
| `doc.oroinc.com/community/release-process/` | banner **7.0 (latest)**. 7.0 LTS March 2026 → March 2030 (2032 extended). **CE patch window: 7.0 = March 2026 → March 2027; 6.1 = March 2025 → March 2026, expired** | `phase2-release-process-recheck` |

**So:** the 7.0 documentation page instructs you to clone a repository whose `master` pins 6.1.6,
and no 7.0 Community application image has ever been published. The official Docker demo path
delivers **6.1.6 CE**, and there is no variant of it — branch, tag, or `ORO_IMAGE_TAG` override —
that delivers 7.0. Overriding the tag would reference an image that does not exist.

This is not a defect in this repo's plan. It is Oro shipping 7.0 documentation over a 6.1 demo.

### Decision D1 — required before any task below runs

| | Option | What it costs | What it changes |
|---|---|---|---|
| **A** *(recommended)* | **Accept 6.1.6 CE.** Amend spec §1 target to "6.1 LTS CE — the newest the official demo publishes", record why | Nothing in the build. One spec amendment | Nothing else. §3 service list, §4 expected absences, §5 acceptance criteria and all 13 `validate.sh` checks hold unchanged |
| B | **Reach 7.0 another way** — source install via Composer, or the "Docker services + Symfony Server" path | Large. Needs PHP 8.5 + Node 24 + PNPM, either on the host (a package-state change, closed list) or in an image this project would have to author. `specs/00-environment-spec.md` §2 rejected this path on its merits | Replaces the plan entirely. Phases 3–6 are re-specified |
| C | **Stop and wait** for Oro to publish a 7.0 demo image | Indefinite. Nine months have already passed since the 7.0 LTS release | The project does not proceed |

**Recommendation: A.** The object of this exercise is architecture discovery on Community Edition —
the DBAL message-queue transport, the ORM search engine, the twelve-service topology, the request
path. None of that differs between 6.1 and 7.0; both are CE, both collapse the queue and the search
index into PostgreSQL. Option B trades the one path that is documented and reproducible for a
bespoke build, to gain a version number that changes nothing you are here to observe.

The honest caveat to record under A: **6.1's CE patch window closed in March 2026.** For a local,
HTTP-only, non-production learning box behind no network exposure that is acceptable — but it is
stated, not glossed, and `specs/00-environment-spec.md` §7 ("no production hardening") already puts
this environment out of scope for anything else.

**The rest of this plan is written for option A.** Under B it is discarded, not amended.

---

## 1. Preconditions

- `specs/STATE.md` reads `Plan approved (Phase 2): YES` — `/oro-implement` refuses otherwise.
- Decision D1 recorded.
- `scripts/preflight.sh` returns `PREFLIGHT: GO` at the moment of bring-up, not from an earlier run.

---

## Task 0 — exercise the approval gate (before approval, deliberately)

Closes **G7**, the one piece of scaffolding never actually run.

| | |
|---|---|
| **Command** | Invoke `/oro-implement` while `specs/STATE.md` still reads `Plan approved (Phase 2): NO` |
| **Validation** | It **refuses** and names the unmet gate. It must not clone, pull, or start anything. Assert afterwards: `git status --porcelain docker/` is empty and `docker ps -q \| wc -l` is unchanged |
| **Rollback** | None — nothing is changed. If it *does* change something, that is the finding, and Phase 3 does not start until the command is fixed |

---

## Task 3.1 — verify Docker and Compose v2 (not install)

Phase 1 proved both present, so the spec's "install Docker" task is a **verification**. Re-run
regardless: `CLAUDE.md`'s verification rule is session-scoped.

| | |
|---|---|
| **Command** | `scripts/capture.sh 3 verify-docker -- bash -c 'docker version --format "server={{.Server.Version}} client={{.Client.Version}}"; docker compose version --short; id -nG'` |
| **Validation** | `scripts/capture.sh 3 preflight-pre -- scripts/preflight.sh` → last line `PREFLIGHT: GO`, exit 0. Compose short version begins `2.`. `id -nG` contains `docker` |
| **Rollback** | n/a — read-only |

**No package-state change appears anywhere in this plan.** If preflight reports Docker unreachable,
that is a STOP-AND-ASK, not a silent `apt install`.

---

## Task 3.2 — clone `oroinc/docker-demo` into `docker/`, record the commit SHA

`docker/` already holds `.env.template` and `.gitkeep`, and `git clone` refuses a non-empty target.
Clone to scratch, then copy in.

| | |
|---|---|
| **Command** | `TMP=$(mktemp -d)` <br> `scripts/capture.sh 3 clone-docker-demo -- git clone --depth 1 https://github.com/oroinc/docker-demo.git "$TMP/docker-demo"` <br> `cp -a "$TMP/docker-demo/." docker/` <br> `scripts/capture.sh 3 clone-sha -- git -C docker rev-parse HEAD` |
| **Validation** | `docker/compose.yaml` exists (`validate.sh` exits 2 without it). <br> `(cd docker && docker compose config --services) \| sort \| tr '\n' ' '` lists **12** services and contains all of `db php-fpm-app web ws consumer cron mail volume-init web-init install restore application`. <br> Recorded SHA is a 40-hex string and matches `refs/heads/master` = `202a279343e62ee99b8cc81f78c307a79958f80d` **as observed 2026-09-06** — a different SHA is not an error, it is a moved upstream, and it gets recorded rather than forced. <br> `grep -E '^ORO_IMAGE_TAG=' docker/.env` → `6.1.6` (the D1 assumption, asserted rather than trusted) |
| **Rollback** | **CONFIRM.** `find docker/ -mindepth 1 ! -name .env.template ! -name .gitkeep -delete` — deletes only the clone, inside a directory `.gitignore` already excludes. Not `rm -rf`; still confirmed, because it is a bulk delete |

Closes **G1** (image tags) and **G2** (`ORO_INSTALL_OPTIONS`) with the repo's own file rather than
the fetched copy.

---

## Task 3.3 — `docker/.env`: do **not** overwrite it

Planning correction. `docker/.env.template` says "copy to `docker/.env`". That is wrong, and acting
on it would break the stack.

Upstream ships a complete `.env` — image tags, `ORO_DB_*` credentials, the WebSocket and nginx
upstream JSON, `ORO_MQ_DSN=dbal:`, `ORO_SEARCH_ENGINE_DSN=orm:?prefix=oro_search`. Compose reads it
automatically from the project directory. Overwriting it with our nine-line template would strip
every one of those and produce a stack that fails in a way that looks like an Oro bug.

The doc page is explicit and agrees: *"The configuration is entirely predefined; the only thing you
can change is the application's domain."* Our template's real role is **documentation of the knobs**,
not a source file.

| | |
|---|---|
| **Command** | No copy. Correct the template's own header so it cannot mislead later: rewrite the first three comment lines of `docker/.env.template` to state that upstream ships `.env`, that it must not be overwritten, and that this file is a reference index of the variables |
| **Validation** | `grep -c '^ORO_' docker/.env` ≥ 40 (upstream's, intact — it was 60+ when fetched). <br> `grep -E '^ORO_APP_DOMAIN=' docker/.env` → `oro.demo`, matching the `/etc/hosts` entry task 3.7 adds. <br> `git check-ignore -q docker/.env` exits 0 — the credential-bearing file is ignored. <br> `scripts/capture.sh 3 compose-config -- bash -c 'cd docker && docker compose config'` exits 0, and the emitted log contains `[REDACTED]` and no bare `ORO_DB_PASSWORD=` value |
| **Rollback** | `git checkout -- docker/.env.template` (tracked). `docker/.env` is never modified, so there is nothing to undo |

---

## Task 3.4 — preflight, then free the memory — **CONFIRM**

Phase 1's governing finding: ~6.8 GiB available against a ~5 GiB peak is about 1.8 GiB of margin,
with 2 GiB of untouched swap behind it. `preflight.sh` returns GO honestly against its 5000 MiB
threshold, but a PHP install that starts swapping on four cores does not fail cleanly, it stalls.
So this is a **step**, not an exception handler.

| | |
|---|---|
| **Command** | `scripts/capture.sh 3 preflight-gate -- scripts/preflight.sh`, then **STOP AND ASK**, then `scripts/capture.sh 3 magento-stop -- scripts/magento-stack.sh stop` |
| **Ask, verbatim** | "Stop the 16 running `docker_magento` containers. `docker stop` only — no volume is touched, no data removed, nothing is pruned. Reversible with `scripts/magento-stack.sh start`. Your Magento environment is unavailable until then." |
| **Validation** | `scripts/magento-stack.sh status` → `running: 0`, `total: 16` — total unchanged is the proof nothing was removed. <br> Re-run `preflight.sh`: `PREFLIGHT: GO` and `ram available` materially above the 6.8 GiB baseline (Phase 1 measured the Magento stack holding ~8.7 GiB with the desktop) |
| **Rollback** | `scripts/magento-stack.sh start` → `running: 16`. Verify with `docker ps --filter label=com.docker.compose.project=docker_magento -q \| wc -l` |

`magento-stack.sh` cannot `down`, `prune`, or `rm` — it rejects every verb but `status|stop|start`.
That is why it exists.

---

## Task 3.5 — `docker compose up restore`

Pulls the images (size unmeasured — **G10**) and restores the pre-built database.

| | |
|---|---|
| **Command** | `scripts/capture.sh 3 compose-up-restore -- bash -c 'cd docker && docker compose up restore'` |
| **Validation** | `capture.sh` preserves the exit code — assert **0**. <br> `(cd docker && docker compose ps -a --format '{{.Service}} {{.State}} {{.ExitCode}}')` → `restore` is `exited 0`. `exited` here is **correct**, not a failure. <br> `(cd docker && docker compose exec -T db pg_isready)` → `accepting connections`. <br> Row count on `oro_user` ≥ 1 (`validate.sh` check 5 in isolation) — a restored *database*, which is not yet a working *application* |
| **Rollback** | `(cd docker && docker compose down)` — **never `down -v`**. `down` removes containers and the network; named volumes survive, so the restore is not repeated. `down -v` destroys the database and is on the closed list |
| **On failure** | Stop. Root-cause from the captured log with `grep`, never by re-running. Record the failure *and* the fix in `docs/troubleshooting.md`. Do not paste the log into context |

Expect the pull to dominate wall-clock. If it fails on `could not find an available, non-overlapping
IPv4 address pool`, that is **G9** biting — a Docker address-pool exhaustion that surfaces at `up`
time and reads like a compose fault. It is not one.

---

## Task 3.6 — `docker compose up application`

| | |
|---|---|
| **Command** | `scripts/capture.sh 3 compose-up-application -- bash -c 'cd docker && docker compose up -d application'` |
| **Why `-d`** | `application` runs `true` and exists only to pull `web`, `consumer` and `cron` up through its `depends_on` graph. In the foreground the wrapper stays attached to that graph, and the capture exiting would take the stack down with it. `-d` starts the dependencies and lets the aggregator exit, which is the documented behaviour |
| **Validation** | `scripts/capture.sh 3 validate-post-application -- scripts/validate.sh`. Assert: checks **1–6 and 8–10 PASS**; check 7 `MANUAL`; checks **11–13 `EXPECTED-ABSENT`** — Redis, RabbitMQ and Elasticsearch absent is the architectural result this environment exists to demonstrate, proven from `compose config --services`, not assumed. <br> Check 6 is not optional: **no live `oro:message-queue:consume` process means the install is broken, not partial.** <br> Checks 2 and 3 use `curl -H 'Host: oro.demo'` against `127.0.0.1`, so they pass *before* `/etc/hosts` exists — 3.7 is browser convenience, not a dependency |
| **Rollback** | `(cd docker && docker compose stop)` — containers stay, state stays, restart is `start`. `down` only if the stack must be rebuilt |

Full validation is Phase 4. This is the per-task check that the step succeeded, per the one-step-at-a-time rule.

---

## Task 3.7 — `/etc/hosts` entry — **CONFIRM** (system file)

**Pre-state, measured read-only 2026-09-06** — the rollback is verifiable against it:

- 10 lines; `md5sum` = `deb7c2f90acdc83235b4aecf8ae21a53`
- `grep -c oro.demo /etc/hosts` = **0**
- lines 3–4 already read `127.0.0.1 php-docker.test` and `127.0.0.1 magento.docker` — this append
  follows an idiom already established on this host, it does not introduce one

| | |
|---|---|
| **Reverse command, captured *before* the edit** | `sudo sed -i '/^127\.0\.0\.1[[:space:]]\+oro\.demo$/d' /etc/hosts` — recorded in the plan and in `CHANGELOG.md` **before** the write, not derived afterwards |
| **Backup, also before** | `sudo cp -a /etc/hosts /etc/hosts.oro-bak-$(date +%Y%m%dT%H%M%S)` |
| **Ask, verbatim** | "Append `127.0.0.1  oro.demo` to `/etc/hosts`. One line added, nothing modified or removed. Backup at `/etc/hosts.oro-bak-<ts>`; reverse is the single `sed -i` above. Needs sudo." |
| **Command** | `printf '127.0.0.1\toro.demo\n' \| sudo tee -a /etc/hosts >/dev/null` |
| **Validation** | `getent hosts oro.demo` → `127.0.0.1 oro.demo` (Phase 1 recorded it not resolving). <br> `wc -l /etc/hosts` → **11**, exactly one more. <br> `diff <(sudo cat /etc/hosts.oro-bak-<ts>) /etc/hosts` shows exactly one added line and no other change. <br> `curl -sI http://oro.demo/` → 200/301/302 |
| **Rollback** | The captured `sed`, then assert `md5sum /etc/hosts` returns to `deb7c2f90acdc83235b4aecf8ae21a53` |

The md5 round-tripping is the point: it makes "I undid it" checkable instead of asserted.

---

## 2. Phase-level rollback

Undo in reverse order. Nothing here is destructive, and no step needs the previous one undone first.

| Step | Reverse | Asserted after |
|---|---|---|
| 3.7 | `sudo sed -i '/^127\.0\.0\.1[[:space:]]\+oro\.demo$/d' /etc/hosts` | md5 back to `deb7c2f9…` |
| 3.6 / 3.5 | `(cd docker && docker compose down)` — **no `-v`** | `docker ps -a --filter label=com.docker.compose.project=docker -q` empty |
| 3.4 | `scripts/magento-stack.sh start` | `running: 16` |
| 3.2 | **CONFIRM** targeted delete of `docker/` contents | `docker/` holds `.env.template .gitkeep` |

The Oro *images* stay on disk after a full rollback. That is deliberate — 328 GiB free, and
re-pulling them is the expensive part. **Do not `docker system prune`**: closed list, and there is
no disk argument for it.

---

## 3. STOP-AND-ASK points in this phase

Three, and no standing grant carries between them or between sessions:

1. **3.4** — stopping `docker_magento`
2. **3.7** — writing `/etc/hosts`
3. **3.2 rollback only** — bulk delete of `docker/` contents, if a rollback is ever needed

Nothing in this plan calls `docker compose down -v`, `docker system prune`, `docker volume rm`,
`rm -rf`, `apt`, or any firewall command. If a step appears to need one, that is a plan defect and
it comes back here.

---

## 4. Out of scope for Phase 3

The second checkout running `docker compose up install` (spec §2, learning-plan exercise 1.3) is
**not** in this phase. It doubles the memory peak and would run concurrently with a working stack.
It belongs after Phase 4 has validated the `restore` environment, as its own gated task.

Also out: TLS, hardening, EE components, custom bundles, tuning, and any change to `docker_magento`
beyond `stop`/`start`.

---

## 5. Gaps closed and opened by this planning phase

**Closed:**

| # | How |
|---|---|
| G1 | Image tags read from upstream `.env`: `ORO_IMAGE_TAG=6.1.6`, `ORO_BASELINE_VERSION=6.1-latest`, `ORO_PG_VER=17.2-alpine`. Digests still unpinned |
| G2 | `ORO_INSTALL_OPTIONS=` — **empty upstream**. The install service passes no options at all |
| G3 | Both doc pages re-fetched this session; version banner reads **7.0 (latest)** on each. The banner is confirmed, not inferred |
| G6 | **Redaction proven against real credentials.** `phase2-upstream-env` raw contained 3 populated `ORO_*PASSWORD=` values and a password-bearing `postgres://` DSN; the emitted log contains 4 `[REDACTED]` and 0 surviving values. This was the synthetic-only gap, and it is now a real test |

**Opened:**

| # | Gap | Closes at |
|---|---|---|
| G10 | Oro image pull size unmeasured — matters for wall-clock, not for disk | Phase 3, task 3.5 |
| G11 | **`capture.sh` redaction is key=value, URI and `Bearer`-shaped only. Credentials written as prose pass straight through.** Found live: the demo page states the back-office login and two storefront demo accounts in sentences. Scrubbed manually to `[REDACTED-MANUAL]` in `logs/phase2-demo-docker-page-*.log`; recorded in `docs/troubleshooting.md` | Phase 3 — extend the redaction pass, or accept and document the limit |
| G12 | `docker/.env.template`'s instruction to copy it over `docker/.env` is wrong and would break the stack | Phase 3, task 3.3 |

Still open from Phase 1: **G4** (real memory footprint — Phase 4), **G5** (whether `restore` alone
yields a working app — Phase 4), **G7** (gate test — task 0 above), **G8** (learning plan says PHP
8.4 — Phase 6), **G9** (Docker address-pool bound — first `compose up`).

---

## 6. `UNVERIFIED:` items

- `UNVERIFIED:` **image digests.** Tags are now known; the digest behind `6.1.6` is not pinned and
  is recorded at pull time (Phase 3/5).
- `UNVERIFIED:` **upstream `master` SHA at clone time.** `202a279343e62ee99b8cc81f78c307a79958f80d`
  was observed 2026-09-06 by `git ls-remote`. Upstream can move between now and the clone; task 3.2
  records what it actually gets.

Everything else in this document was fetched or executed in the session that wrote it. The two
`UNVERIFIED:` items carried from `specs/00-environment-spec.md` §10 covering doc banners and
`ORO_INSTALL_OPTIONS` are **closed** by G3 and G2 above; §10 is corrected in Phase 6.
