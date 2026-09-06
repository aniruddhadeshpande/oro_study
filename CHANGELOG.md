# Changelog

One entry per step: what changed, why, and the validation result.

## 2026-09-06 — Setup: agentic scaffolding

**What changed**
- Workspace tree created at repo root: `specs/ scripts/ runbook/ logs/ docker/ .claude/commands/`.
- `runbook/oro-commerce-architecture-runbook.md` moved from `docs/` (git mv, history preserved).
- `CLAUDE.md` — the spec's prime directives and anti-patterns as enforceable rules with triggers:
  a closed STOP-AND-ASK list with no standing grants, the `UNVERIFIED:` rule, the redaction rule,
  the evidence rule, Compose v2 only, and the consumers-mean-broken-not-partial rule.
- `specs/STATE.md` — durable resume point, read first by every phase command.
- `.claude/commands/oro-{spec,discover,plan,implement,validate,evidence,document,summary}.md` —
  one command per spec phase, each gating on the previous phase and carrying a `model:` field.
- `scripts/capture.sh`, `preflight.sh`, `validate.sh`, `magento-stack.sh`.
- `.gitignore` — excludes the `docker-demo` clone, all real `.env` files, and `logs/raw/`
  (pre-redaction scratch). Redacted logs are tracked: evidence is a deliverable.

**Why**
The spec is an instruction set with directives that erode across context compaction and session
boundaries — spec-before-action, one-step-at-a-time, approval before irreversible ops, no invented
facts. Encoding them as a governance file plus phase-gated commands plus an on-disk state file makes
the workflow the path of least resistance rather than something to remember.

**Validation**
| Check | Result |
|---|---|
| `bash -n` on all four scripts | PASS |
| Redaction: `POSTGRES_PASSWORD`, DSN userinfo, `api-key`, `Bearer` token through `capture.sh` | PASS — all `[REDACTED]`; `grep` finds no secret value in tracked `logs/` |
| `preflight.sh` idempotency, two consecutive runs | PASS — identical verdicts and exit code; only the live MemAvailable figure drifts (7344 → 7332 MiB) |
| `preflight.sh` on this host | GO — docker 28.3.3, compose 2.39.1, port 80 free, 7.3 GiB available, 328 GiB disk; note: 16 `docker_magento` containers up |
| `magento-stack.sh down -v` (guardrail) | PASS — refused, exit 64. The script has no path to `down`, `prune`, or `rm` |
| `validate.sh` with no stack present | PASS — exit 2 with "the stack has not been cloned yet (Phase 3 task 2)" |

**Not yet verified**
- Command phase gating (`/oro-implement` refusing an unapproved plan) — the commands load at session
  start, so this is checked on the next session, not this one.
- `validate.sh` checks 1–13 against a live stack — no stack exists yet by design.

**System state after this entry:** unchanged. Nothing was installed, started, or stopped.

## 2026-09-06 — Phase 0 pre-check: target version confirmed

**What changed**
- `specs/STATE.md` records two verified facts so later phases do not re-fetch them: the current LTS,
  and the docker-demo service list with its long-running / one-shot split.
- Scope for the next chunk agreed: Phases 0 → 2, stopping at the Phase 2 approval gate.

**Why**
Spec Phase 0 requires confirming the current LTS against the release-process page before starting,
and escalating if it has moved on. Doing that read-only check now means Phase 0 starts from a
settled fact rather than spending an Opus turn on a fetch. The service split is recorded because
`validate.sh` check 1 depends on it — a one-shot container showing `Exited` is correct behaviour,
and misreading it as a failure is the kind of error that produces a wrong troubleshooting doc.

**Validation**
| Check | Result |
|---|---|
| Current LTS per https://doc.oroinc.com/community/release-process/ | **7.0 LTS**, released March 2026, supported to March 2030 (2032 Extended). Cadence: one LTS each March. Dev branch 7.1. |
| Matches the spec's target (7.0 LTS CE)? | YES — no discrepancy to escalate |
| docker-demo services per upstream `compose.yaml` | 12 services; only `web` binds a host port (`published: 80`) |

**Not yet verified**
- Phase gating in practice (`/oro-implement` refusing an unapproved plan). The `/oro-*` commands
  were created after that session started, so they were never registered. Checked next session.

**System state after this entry:** unchanged. No Docker operations, no `/etc/hosts`, Magento stack
still running with 16 containers.

## 2026-09-06 — Phase 0: Specification

**What changed**
- `specs/00-environment-spec.md` written: target and edition, platform requirements, chosen install
  path with the rejected alternatives and why, the twelve expected components with an acceptance
  criterion each, the startup dependency graph, the expected-absent EE components, the criteria →
  `validate.sh` mapping, out-of-scope list, accepted risks, and the `UNVERIFIED:` register.
- `scripts/validate.sh` reconciled with the spec (two disagreements, script changed not the claim):
  check 1's long-running set now includes `mail`, and the comment records that `application` is a
  one-shot aggregator whose `Exited` status is correct.
- `specs/STATE.md` rewritten. The previous "do not re-fetch these" instruction was wrong and has
  been replaced: CLAUDE.md's verification rule is session-scoped, so carried-forward facts get
  re-confirmed before they are written into an artefact.

**Why**
Prime directive 1 — specification before action. The acceptance criteria have to exist before the
work that will be judged against them, otherwise they get written to match whatever happened.

The component split is the substantive content. Five of the twelve services are designed to exit,
`application` among them, and its `Exited` status is the mechanism by which the documented
`docker compose up application` works. That is the most likely thing to be misread as a broken
install, so it is stated in the spec and encoded in the validation script rather than left to
judgement at Phase 4.

**Validation**
| Check | Result |
|---|---|
| Current LTS, re-fetched this session | **7.0 LTS**, March 2026 → March 2030, CE patches to March 2027, cadence annual, dev 7.1 |
| Matches spec target (7.0 LTS CE)? | YES — no discrepancy, no escalation |
| `compose.yaml` service inventory, fetched this session | 12 services; 7 long-running, 5 one-shot; only `web` binds a host port |
| Platform requirements, fetched this session | PHP >= 8.5, PG >= 17.6 CE / >= 18.3 EE, Node >= 24.11.0, PNPM >= 10.7.0; ES and RabbitMQ confirmed EE-only |
| Every acceptance criterion maps to a numbered `validate.sh` check | YES — 13/13 after the two fixes |
| `bash -n scripts/validate.sh` | PASS |
| `scripts/validate.sh` with no stack | PASS — exit 2, "the stack has not been cloned yet" |

**Discrepancy recorded**
`docs/oro-commerce-learning-plan.md` states PHP >= 8.4; the requirements page states >= 8.5, and the
learning plan records none of the PostgreSQL, Node or PNPM minimums. Not a blocker — the requirement
is met inside the official image and nothing installs PHP on the host. Correction deferred to
Phase 6, where the study artefacts are revised from observation.

**Outstanding `UNVERIFIED:`** — 3, registered in spec §10: doc version banners for two pages fetched
this session (content used, banner not restated in the extract); image tags and digests; the
contents of `ORO_INSTALL_OPTIONS`. The last two resolve in Phase 3.

**System state after this entry:** unchanged. No Docker operations, no `/etc/hosts`, Magento stack
still running with 16 containers.

---

## 2026-09-06 — Phase 1: Environment Discovery

**What changed:** `docs/01-environment-discovery.md` written (new). `specs/STATE.md` rewritten to
Phase 1 COMPLETE. Twelve evidence logs added under `logs/phase1-*`. No system state altered — every
command run in this phase was read-only.

**Why:** the specification's Phase 3 was written against a generic host. Three of its assumptions
needed testing against this machine before a plan could be built on them, and the phase exists to
turn assumptions into measurements.

**The three assumptions, tested rather than repeated**

| Spec assumption | Result | Consequence |
|---|---|---|
| Docker must be installed | **False** — 28.3.3 + Compose v2.39.1 present, user in `docker` group, daemon answers without `sudo` | Phase 3 task 1 becomes a verification (`preflight.sh` GO). No package-state change anywhere in the build |
| Port 80 may collide | **False** — port 80 unbound. `docker_magento` holds 443/8081/9200/15672 only; 5432 and 6379 are not host-bound at all | No port remapping in `docker/.env`. `ORO_APP_DOMAIN=oro.demo` on :80 as documented |
| RAM sufficiency assumed | **The binding constraint** — 6.8 GiB available against a ~5 GiB estimated Oro peak, ~1.8 GiB margin, 2 GiB swap unused | `magento-stack.sh stop` moves into the Phase 2 plan as a *step*, not a contingency. Confirmation still required each time |

**Validation**

| Check | Result |
|---|---|
| Every findings row traces to a file in `logs/` | PASS — 12 cited slugs, 12 resolve, 0 untraced |
| Every captured log is cited in the document | PASS — 0 uncited |
| All Phase 1 commands exited 0 | PASS |
| `scripts/preflight.sh` | **GO** — daemon OK, compose OK, port 80 free, RAM 7020 MiB (need 5000), disk 328 GiB (need 20), `docker_magento` NOTE |
| Redaction across tracked `logs/` (excluding `raw/`) | PASS — only `[REDACTED]` matches, and only in the Phase 0 self-test. See caveat below |
| System state unchanged | PASS — 16 `docker_magento` containers still up, `/etc/hosts` untouched, `docker/` still holds only `.env.template` and `.gitkeep` |

**Findings not anticipated by the spec:** 7 bridge networks occupy 172.17–172.23 consecutively;
`/etc/hosts` already carries `magento.docker` and `php-docker.test`, so the Oro entry is an append
in an established idiom; 2.7 GB of images and 1.2 GB of build cache are reclaimable and are **not**
to be pruned — 328 GiB free removes any argument for touching the closed list.

**Caveat on the redaction result:** it is a pass against a synthetic self-test only. Nothing run in
Phase 1 emitted a credential, because the credential-bearing command (`docker compose config`) has
no compose file to read yet. The real test is the first such capture in Phase 3 (G6).

**Gap list:** 9 gaps registered, G1–G9, each naming the phase where it closes. G1/G2 (image tags,
`ORO_INSTALL_OPTIONS`) close at Phase 3 task 3.2; G4 (real memory footprint) at Phase 4 and it is
the number Phase 7 should report; G7 (`/oro-implement` refusal path never exercised) is cheapest to
close immediately after Phase 2 is written.

**Outstanding `UNVERIFIED:`** — 4, up from 3. The three in spec §10 stand. One added: the Docker
default address-pool upper bound (`/etc/docker/daemon.json` is absent and this Docker version does
not report the pool in `docker info`, so the remaining /16 slot count is not determinable without
creating a network — out of scope for a read-only phase). Low risk; recorded because pool exhaustion
surfaces at `up` time, not `config` time, and is easily misread as a compose-file fault.

**System state after this entry:** unchanged.

---

## 2026-09-06 — Phase 2: Plan

**Wrote** `specs/01-implementation-plan.md` (task 0 + tasks 3.1–3.7, each with command, validation
and rollback) and `docs/troubleshooting.md` (entry T1). Rewrote `specs/STATE.md`. Read-only
throughout: seven captures, all network GETs or `git ls-remote`, nothing on the host modified.

### The finding: the spec's target version cannot be reached by the spec's chosen path

| Evidence | Result | Log |
|---|---|---|
| `git ls-remote --heads --tags oroinc/docker-demo` | branches `5.0 5.1 6.0 master`; **no `7.0`, no tags** | `phase2-remote-refs` |
| `master:.env` | `ORO_IMAGE_TAG=6.1.6`, `ORO_BASELINE_VERSION=6.1-latest`, `ORO_DB_VERSION=17.2` | `phase2-upstream-env` |
| Docker Hub `oroinc/orocommerce-application` | 5 tags, newest **6.1.6** pushed **2025-12-18**. No 7.0 | `phase2-dockerhub-tags` |
| Docker Hub `oroinc/runtime` | 6 tags, newest `6.1-latest` | `phase2-runtime-tags` |
| Docker Hub `oroinc/` namespace (46 repos) | whole `orocommerce-application*` family last pushed 2025-12-18 | `phase2-oroinc-namespace` |
| Demo docs page | banner **7.0 (latest)**; instruction is a bare `git clone` — i.e. `master` | `phase2-demo-docker-page` |
| Release-process page | banner **7.0 (latest)**. CE patch: 7.0 = Mar 2026→Mar 2027; **6.1 = Mar 2025→Mar 2026, expired** | `phase2-release-process-recheck` |

Oro ships 7.0 documentation over a 6.1 demo. No 7.0 Community application image has ever been
published, so an `ORO_IMAGE_TAG=7.0.x` override would reference an image that does not exist. This
is **Decision D1**, plan §0: accept 6.1.6 and amend spec §1 (recommended), rebuild for 7.0 by a path
the spec already rejected on its merits, or stop. Phase 3 does not start until it is answered.

Nothing about the exercise changes under 6.1: CE is CE — DBAL transport, ORM search engine, the same
twelve services, the same collapse of both async subsystems into PostgreSQL.

### Two defects found in this repo's own artefacts

**`docker/.env.template` is wrong and acting on it would break the stack** (G12). It says "copy to
`docker/.env`". Upstream ships a complete `.env` — image tags, `ORO_DB_*`, the nginx and WebSocket
upstream JSON — and compose reads it automatically. Overwriting it with our nine-line template
strips all of that and produces a failure that looks like an Oro bug. Plan task 3.3 is now *do not
overwrite*, plus a header correction. The doc page agrees: "the only thing you can change is the
application's domain."

**`capture.sh` redaction misses prose credentials** (G11, `docs/troubleshooting.md` T1). It matches
`key=value`, `scheme://user:pass@host`, and `Bearer`/`Basic`. The demo page states its credentials
in sentences; three such lines reached a tracked log. Scrubbed to `[REDACTED-MANUAL]`, repo-wide
sweep clean, `logs/raw/` unaffected (gitignored by design). The filter is not broken — its coverage
is narrower than the guarantee the project assumes, and prose is what documentation uses.

### Validation

| Check | Result |
|---|---|
| Gate: STATE.md reads Phase 1 COMPLETE | PASS |
| Every plan task has command + validation + rollback | PASS — 8 of 8 |
| `/etc/hosts` reverse `sed` captured *before* any edit | PASS — with pre-state md5 `deb7c2f9…`, 10 lines, 0 `oro.demo` |
| No closed-list command anywhere in the plan | PASS — no `down -v`, `prune`, `volume rm`, `rm -rf`, `apt`, firewall |
| Redaction on real credentials | **PASS** — raw held 3 populated `ORO_*PASSWORD=` plus a password-bearing `postgres://` DSN; emitted log has 4 `[REDACTED]`, 0 survivors |
| Prose-credential sweep across `logs/ docs/ specs/ runbook/ CHANGELOG.md` | PASS — clean after manual scrub |
| System state unchanged | PASS |

### Gaps

**Closed: G1** (image tags read from upstream `.env`; digests still unpinned), **G2**
(`ORO_INSTALL_OPTIONS=` — empty upstream, the install service passes nothing), **G3** (both doc
banners confirmed **7.0 (latest)**, no longer inferred from figures), **G6** (redaction proven
against real credentials — this was the synthetic-only gap).

**Opened: G10** image pull size unmeasured · **G11** prose-credential redaction · **G12**
`.env.template` instruction wrong.

**Still open:** G4, G5 (Phase 4) · G7 (task 0, before approval) · G8 (Phase 6) · G9 (first `up`).

**Outstanding `UNVERIFIED:`** — 3, down from 4. Two closed by G2/G3; one added (upstream `master`
SHA may move between `ls-remote` and clone). Remaining: image digests, Docker address-pool bound,
clone-time SHA.

**System state after this entry:** unchanged. 16 `docker_magento` containers running, `oro.demo`
does not resolve, `docker/` holds `.env.template` and `.gitkeep`, port 80 free.

## 2026-09-06 — Decision D1 resolved · G7 gate test PASS

**What changed and why.** Phase 2 ended blocked on D1: the spec targeted 7.0 LTS CE, but the chosen
install path cannot deliver it — `oroinc/docker-demo` has no 7.0 branch and no tags, its `master`
pins `ORO_IMAGE_TAG=6.1.6`, and Docker Hub has never carried a 7.0 `orocommerce-application` image.
The user selected **option A: build against 6.1.6 CE**.

Three artefacts amended as a consequence:

| File | Change |
|---|---|
| `specs/00-environment-spec.md` §1 | Target rewritten 7.0 LTS → **6.1.6 CE**, with the D1 rationale, the accepted expired-patch-window caveat, and a note that the platform-requirements table is 7.0's and therefore a forward reference (upstream pins PG **17.2**, not 17.6) |
| `CLAUDE.md` verification rule | **6.1 is now the correct doc line**; 5.0/5.1/6.0 are wrong pages; 7.0 pages readable but must be labelled forward references, never asserted about the running system |
| `specs/01-implementation-plan.md` §0 | Marked RESOLVED — option A. Tasks 3.1–3.7 were written against 6.1.6 already, so none changes |

**Why this is not a downgrade of the learning objectives.** CE is CE across the line: DBAL
message-queue transport into `oro_message_queue`, ORM search engine into Postgres EAV,
Elasticsearch / RabbitMQ / `oro/redis-config` still EE-only, the same 12-service topology and
request path. What is lost is the CE patch window, which closed for 6.1 in March 2026 — accepted
explicitly for a local, HTTP-only, non-production box with no real data.

**G7 gate test — PASS (plan task 0).** `/oro-implement` invoked while the `Plan approved (Phase 2)` line in `specs/STATE.md` read
`Plan approved (Phase 2): NO`. It refused and named that line as the unmet gate. No task selected,
no `capture.sh` invocation, no writes.

| Assertion | Expected | Observed | Result |
|---|---|---|---|
| Refusal names the unmet gate | yes | the `Plan approved (Phase 2)` line, then :17 | PASS |
| `git status --porcelain docker/` | empty | empty | PASS |
| `docker/` contents | `.env.template` `.gitkeep` | same | PASS |
| Running containers | 16 | 16 | PASS |
| `docker_magento` containers | 16 | 16 | PASS |
| `getent hosts oro.demo` | no resolution | does not resolve | PASS |
| `/etc/hosts` md5 | `deb7c2f90acdc83235b4aecf8ae21a53` | unchanged | PASS |
| `logs/phase3-*` written | 0 | 0 | PASS |
| Phase 3 CHANGELOG entries | 0 | 0 | PASS |
| Pre vs post state block | identical | byte-identical | PASS |

Evidence: `logs/phase2-g7-gate-test-pre-20260906T180825.log`,
`logs/phase2-g7-gate-test-post-20260906T180841.log`.

**G7 closed** — and it is the one scaffolding check that cannot be re-run in this repo, because it
only exists while the approval flag reads NO.

**Gaps:** G7 closed. G1–G3, G6 closed earlier in Phase 2. Open: G4, G5 (Phase 4), G8 (Phase 6),
G9 (first `up`), G10 (image pull size), G11 (prose-credential redaction), G12 (documented, fixed in
plan task 3.3).

**`UNVERIFIED:` 3 → 4** — the 6.1 system-requirements page was never fetched, so the PHP and Node
figures for 6.1.6 are unconfirmed and will be read off the running containers in Phase 4.

**State unchanged.** Nothing on the system has been modified through the end of Phase 2.

## 2026-09-06 — Phase 3 begins · plan approved · task 3.1 PASS

**Plan approved.** `specs/STATE.md` now records `Plan approved (Phase 2): YES`, approved by the user
after the G7 gate test passed. Task-level STOP-AND-ASK approvals do **not** follow from it: tasks 3.4
(`magento-stack.sh stop`) and 3.7 (`/etc/hosts` append) each ask again at their own time.

**Task 3.1 — verify Docker and Compose v2 (not install). PASS.**

Re-run rather than carried from Phase 1, because the verification rule is session-scoped.

| Assertion | Expected | Observed | Result |
|---|---|---|---|
| Docker daemon reachable | server responds | server 28.3.3, client 28.3.3 | PASS |
| Compose short version | begins `2.` | `2.39.1` | PASS |
| User in `docker` group | `docker` in `id -nG` | `aniruddha sudo users docker` | PASS |
| `preflight.sh` verdict | `PREFLIGHT: GO`, exit 0 | `PREFLIGHT: GO`, exit 0 | PASS |

Preflight detail: port 80 free · RAM available **9331 MiB** against a 5000 MiB requirement · 328 GiB
free on `/` · `docker_magento` 16 containers up (NOTE, not a failure).

**Headroom is better than Phase 1 measured** — 9331 MiB now against 6.8 GiB then, on the same host
with the same 16 Magento containers running. Phase 1's figure was the pessimistic one; the binding
constraint is still memory, but the margin over the 5 GiB requirement is wider than planned for.
This does not remove task 3.4 — the Oro stack's peak is what matters, and that is still unmeasured.

No state changed: read-only task, no rollback defined or needed. Evidence:
`logs/phase3-verify-docker-20260906T181235.log`, `logs/phase3-preflight-pre-20260906T181240.log`.
