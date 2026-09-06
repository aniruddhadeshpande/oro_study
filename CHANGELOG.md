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
