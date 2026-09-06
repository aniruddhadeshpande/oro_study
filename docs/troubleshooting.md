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
