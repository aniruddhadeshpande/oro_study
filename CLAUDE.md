# OroCommerce Learning Environment — Operating Rules

Governing spec: `docs/oro-commerce-spec-driven-development.md`. This file is the enforceable subset.
Current position in the workflow: **`specs/STATE.md` — read it first, every session.**

Audience for everything you write: a Senior Solution Architect, 13+ years, Magento/Adobe Commerce
background. Do not explain Docker, Linux, or HTTP.

## Workflow — no skipping, no reordering

`0 Spec → 1 Discovery → 2 Plan → 3 Implementation → 4 Validation → 5 Evidence → 6 Docs → 7 Summary`

One phase per `/oro-*` command. Each command reads `specs/STATE.md`, refuses if the prior phase is
incomplete, does its work, rewrites `STATE.md`, appends to `CHANGELOG.md`, prints `Safe to /compact.`

## STOP AND ASK — closed list, every time, no standing grants

An approval granted earlier in this session, or in a previous one, does **not** carry over.

- `docker compose down -v` — destroys the database
- `docker system prune` (any form), `docker volume rm`
- `rm -rf`
- any write to `/etc/hosts`
- package-state changes (`apt install/remove/upgrade`), firewall changes
- stopping or starting the `docker_magento` project (use `scripts/magento-stack.sh`)

Ask in plain terms, state what is destroyed and what the rollback is, then wait.

## Hard rules

**Verification.** Any URL, version number, diagram link, or command not fetched or executed in this
session is prefixed `UNVERIFIED:` wherever it is written. Never emit a plausible-looking Oro doc URL.
Check the version banner on every doc page — this repo targets **7.0 LTS CE**; a page showing 5.1 or
6.1 is the wrong page.

**Secrets.** No credential *value* in `docs/`, `runbook/`, `logs/`, `CHANGELOG.md`, or a commit.
Reference the variable name. `scripts/capture.sh` redacts mechanically; do not bypass it.

**Evidence.** A task is done when its output is in `logs/` and its result is a row in `CHANGELOG.md`.
Not before. `docker compose ps` is never sufficient proof that anything works — a running container
is not a working application.

**Consumers.** An Oro install with consumers not running is **broken**, not partial. Report it that way.

**One step at a time.** Implement → validate → record → move on. Never batch changes and validate at
the end. On failure: stop, find the root cause, do not retry blindly; record the failure *and* the
fix in `docs/troubleshooting.md`.

**Compose v2.** `docker compose`. Never `docker-compose`.

**Console commands** run inside the container: `docker compose exec php-fpm-app php bin/console <cmd>`

## Environment facts (verified 2026-09-06, re-confirm in Phase 1)

- Linux Mint 22, 4 CPU, 15 GiB RAM, 328 GiB free on `/`
- Docker Engine 28.3.3, Compose v2.39.1, user in `docker` group — **do not install Docker**
- Port 80 free. Oro's `web` service is the only host binding (`published: 80`)
- Ports 443 / 9200 / 8081 / 15672 held by the `docker_magento` stack — no collision with Oro
- **RAM is the binding constraint**, not ports. Run `scripts/preflight.sh` before every bring-up.

## Cost control

Model per phase (set in each command's frontmatter; `/model` to switch manually):
Haiku for Discovery and Evidence · Sonnet for Implementation and Validation · Opus for Spec, Plan,
Documentation, Summary. If a Sonnet-run task fails twice, escalate the *diagnosis* to Opus rather
than burning retries.

`/compact` at every phase boundary — `STATE.md` holds the resume point, so nothing needed is
context-resident. Never paste an install or reindex log into context; it goes to `logs/` via
`capture.sh` and is read back with `grep`.

## Writing

Every script and doc section states *what* it does, *why* it is needed, and *what it reveals about
the architecture*. Document from what you observed, not from what the docs claim. Empty sections are
worse than no sections — an empty Known Issues on a first-time install is not credible.
