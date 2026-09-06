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
