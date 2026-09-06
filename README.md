# OroCommerce Learning Environment

A local OroCommerce 7.0 LTS Community Edition environment, built spec-first and documented from
observation. Audience: solution architects coming from Magento/Adobe Commerce.

Governing spec: [`docs/oro-commerce-spec-driven-development.md`](docs/oro-commerce-spec-driven-development.md).
Operating rules: [`CLAUDE.md`](CLAUDE.md). **Current position: [`specs/STATE.md`](specs/STATE.md).**

## Layout

| Path | Contents |
|---|---|
| `specs/` | Specification, implementation plan, and `STATE.md` — the resume point |
| `docs/` | The governing spec, the learning plan, and the architecture docs produced in Phase 6 |
| `scripts/` | Idempotent shell: `capture.sh`, `preflight.sh`, `validate.sh`, `magento-stack.sh` |
| `runbook/` | The living operational runbook |
| `logs/` | Redacted command output — evidence, and a deliverable in its own right |
| `docker/` | The `oroinc/docker-demo` clone (gitignored) and `.env.template` |
| `.claude/commands/` | One slash command per workflow phase |

## Workflow

`/oro-spec → /oro-discover → /oro-plan → /oro-implement → /oro-validate → /oro-evidence →
/oro-document → /oro-summary`

Each command reads `specs/STATE.md`, refuses to run if the previous phase is incomplete, does its
phase, rewrites the state file, appends to `CHANGELOG.md`, and tells you when it is safe to
`/compact`. `/oro-implement` runs exactly one task per invocation.

## Running anything by hand

```bash
scripts/preflight.sh                      # go/no-go: docker, port 80, RAM headroom, disk
scripts/magento-stack.sh status           # the co-resident Magento stack
scripts/capture.sh 3 my-task -- <cmd>     # run <cmd>, keep redacted evidence in logs/
scripts/validate.sh                       # the 13-check table, once a stack exists
```

`preflight.sh` before every bring-up. On this host RAM is the binding constraint, not ports.

## Known constraints

- 4 CPU / 15 GiB RAM. Oro peaks at ~5 GiB during install and reindex, so the co-resident
  `docker_magento` stack gets stopped first — non-destructive, reversible, and always confirmed.
- Community Edition: no Redis config bundle, no RabbitMQ, no Elasticsearch. The DBAL message-queue
  transport and the ORM search engine are used instead. That is an architectural finding to
  document, not a gap to fix.
