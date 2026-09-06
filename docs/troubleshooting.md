# Troubleshooting

Failures found in this project, with the root cause and the fix. Written from what was observed,
not from what a doc claims. A failure with no entry here did not happen.

---

## T1 — `capture.sh` redaction misses credentials written as prose

**Phase 2, 2026-09-06.** Found while capturing an Oro documentation page.

**What happened.** `scripts/capture.sh` redacts three shapes: `key=value` / `key: value` for
credential-named keys, inline passwords in `scheme://user:pass@host` URIs, and
`Bearer`/`Basic` tokens. The demo-environment page states its credentials in *sentences* — a
back-office login and two storefront demo accounts, each of the form "use X as both login and
password". None of the three patterns matched, and the values landed in a **tracked** log under
`logs/`, in violation of the secrets rule.

**Why it matters.** The redaction pass had only ever been exercised against a synthetic self-test
and against `key=value` env output, where it works correctly — the same session proved it strips
three populated `ORO_*PASSWORD=` values and a password-bearing `postgres://` DSN from real
upstream output. The gap is not that redaction is broken. It is that **its coverage is narrower
than the guarantee the rest of the project assumes**, and prose is exactly the shape documentation
uses.

**Fix applied.** The three lines in `logs/phase2-demo-docker-page-20260906T174738.log` were rewritten in place to
`[REDACTED-MANUAL]`, and a repo-wide sweep for the same prose shapes across `logs/ docs/ specs/
runbook/ CHANGELOG.md` returned clean. `logs/raw/` still holds the unredacted capture; that is by
design — it is gitignored pre-redaction scratch and never leaves the host.

**Not yet fixed.** The redaction pass itself is unchanged. Registered as **G11**: either extend it
with prose patterns, or accept the limit and state it — but the current situation, where the
guarantee is broader than the implementation, is the one thing that is not acceptable.

**Rule that follows.** `capture.sh` is a mechanical filter, not a guarantee. Any capture of
human-written prose — a documentation page, a README, a support thread — gets read before it is
committed. Machine output can be trusted to the filter; prose cannot.

---

## T2 — `validate.sh` reported a healthy stack as broken (checks 6 and 10)

**Phase 3, task 3.6, 2026-09-06.** First `validate.sh` run after `docker compose up -d application`
returned `failures: 2` and `VALIDATION: FAILED`. Both failures were defects in the checking script.
The application was correct throughout.

### Check 6 — "no `oro:message-queue:consume` process in container"

Under the project's own rule this reads as *the install is broken, not partial* — the most serious
verdict the harness can return. It was wrong.

The consumer container was running two live processes. The demo stack runs
**`oro:message-queue:transport:consume`** (the lower-level, per-queue consumer, wrapped in
`job-runner.phar` with `--memory-limit=1024 --time-limit=15minutes`), while the check grepped for
`oro:message-queue:consume`. Both are real commands — `console list oro:message-queue` shows five —
so this was not a typo but an assertion about the wrong one. The literal substring does not appear
in the longer command name, so the grep could never match.

**Fix:** match either form — `grep -cE 'oro:message-queue:(transport:)?consume'`.

### Check 10 — `Could not open input file: bin/console`

The container's WORKDIR is `/`, not the application root. Oro lives at **`/var/www/oro`**, so a
relative `php bin/console` cannot resolve. `CLAUDE.md` documented the same relative form, so this
error was baked into the project's own operating rules and would have recurred in every later phase.

**Fix:** absolute path in `validate.sh` (`ORO_ROOT="${ORO_ROOT:-/var/www/oro}"`, overridable), and
the `CLAUDE.md` console-command rule corrected to
`docker compose exec php-fpm-app php /var/www/oro/bin/console <cmd>`.

### Result

Re-run: `failures: 0`, exit 0. Checks 6 and 10 PASS (2 consume processes; pools listed).

### What this reveals

Both defects share a cause: the harness was written from the spec's *expectations* rather than from
the running system, which is exactly what the project's "document from what you observed" rule
exists to prevent — the scripts were simply written before there was a system to observe. A
validation harness that has never run against a working stack has itself never been validated, and
its first run tests the harness at least as much as the subject. Check 6 is the sharper lesson: a
false FAIL on the most severe assertion in the suite trains the reader to distrust the suite.

---

## T3 — `sudo` is unusable from the agent session (no TTY)

**Phase 3, task 3.7, 2026-09-06.** `sudo cp -a /etc/hosts ...` failed with
`sudo: a terminal is required to read the password; either use the -S option to read from standard
input or configure an askpass helper`. `sudo -n true` confirmed passwordless sudo is not configured.
The `!` prefix in the Claude Code prompt runs in the same non-TTY context and failed identically.

**Not worked around, deliberately.** The available workarounds — an askpass helper, a NOPASSWD
sudoers entry, or piping a password with `-S` — are all privilege-state changes on the STOP-AND-ASK
closed list, and the last one would also put a credential in a captured log. The correct move was to
hand the exact commands to the user for execution in a real terminal.

**Consequence to plan for:** any Phase 3+ task requiring root is a **user-executed** task. Write it
so the validation is independent of who ran it, and capture the rollback *before* handing it over —
in this case that is what saved the task when the user (reasonably) ran only the edit and skipped
the backup.

**The lesson that generalises:** a rollback proven by dry-run against the live file is stronger than
one proven by diffing a backup, and it does not depend on the backup having been taken. Recording
the pre-state md5 plus the reverse command *before* the edit made the rollback verifiable even
though the planned artefact was missing. Prefer that ordering everywhere.

---

## T4 — `oro:search:reindex` reports success while doing nothing

**Phase 6, check-7 experiment, 2026-09-06.** Not a failure of the system — a failure mode of the
*interface to* the system, and the more dangerous kind because it is silent and green.

With `consumer` stopped, `php /var/www/oro/bin/console oro:search:reindex` printed:

```
Started reindex task for all mapped entities
Reindex finished successfully.
```

and exited 0. No reindexing had occurred or could occur. `oro_message_queue` went 0 → 1; the work
sat there. Held 45 seconds: depth rose to 2 (cron adding more) and **nothing drained**. Restarting
the consumer drained it to 0 within 8 seconds.

**Root cause:** the command's job is to enqueue. Its exit code and its message describe the enqueue,
not the reindex. This is correct behaviour, wrongly readable.

**Why it matters:** wired into a deploy script, a smoke test or a CI gate, this returns green for an
operation that has not started. The Magento habit of treating a reindex exit code as completion
transfers badly.

**The assertion to use instead:** `select count(*) from oro_message_queue` returning to its prior
depth. Not container state — see T5.

---

## T5 — a dead consumer is invisible to every check in the stack

**Same experiment.** While the consumer was stopped for ~60 seconds:

- storefront `curl -sI http://oro.demo/` → **200** throughout
- `docker compose ps` — every long-running service `running`
- all three healthchecks (`db` `pg_isready`, `php-fpm-app` `php-fpm-healthcheck`, `web` `curl -If`) passing
- `validate.sh` checks 1–5 and 8–10 would all have passed

**Root cause:** only 3 of 12 services define a healthcheck — `db`, `php-fpm-app`, `web`.
`consumer`, `cron` and `ws` define none. The async tier is entirely unmonitored by the compose
stack, and the synchronous tier is genuinely healthy while the async tier is dead, so no
HTTP-level probe can detect it either.

**Fix (monitoring, not code):** alert on **queue depth and oldest-message age**, never on container
liveness. Two derived rules from the same experiment:

- A *rising* depth with the consumer `running` is a stuck consumer; a rising depth with it absent is
  a dead one. Both look identical from HTTP.
- `cron` keeps enqueuing while the consumer is down, so depth grows even with zero user activity.
  A quiet system is not a safe one.

**Related, and easy to misread in the opposite direction:** inside the consumer container, PID 7
(`job-runner.phar`) showed 28:37 elapsed while the actual console process showed 13:19. The runner
respawns the consumer on `--time-limit=15minutes --memory-limit=1024`. **A consumer process younger
than its container is healthy** — the design recycles it to bound memory. Reading a short-lived
worker as "crash-looping" sends the responder after a non-problem.

---

## T6 — pre-existing data defect in the shipped demo dataset

**Phase 6, during the check-7 reindex.** `oro:search:reindex` logged:

```
app.ERROR: Errors occurred while preparing data for the search index.
For the entity "oro_sale_quote", the following fields: "poNumber" have wrong type.
```

The reindex completed and the queue drained to 0; validation checks 9 (storefront search, 626 KB
returned) and 5 (schema) pass. So this is **not** blocking, and it is not caused by anything done in
this project.

**Root cause:** a type mismatch between the search-index mapping for `oro_sale_quote.poNumber` and
the value in the restored demo dataset. It ships that way in
`oroinc/orocommerce-application-init:6.1.6`.

**Recorded, not fixed.** Fixing vendor demo data is out of scope and would make this environment
non-representative. It is documented because a reader who runs a reindex will see this error and
needs to know it is inherited, expected, and harmless here — and because it is a useful reminder
that "reindex finished" and "reindex was clean" are different claims (see T4).
