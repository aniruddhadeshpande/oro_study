---
description: Phase 1 — record the environment as found; changes nothing
model: claude-haiku-4-5-20251001
allowed-tools: Bash(scripts/capture.sh:*), Bash(uname:*), Bash(cat:*), Bash(nproc:*), Bash(free:*), Bash(df:*), Bash(which:*), Bash(docker --version), Bash(docker compose version), Bash(id:*), Bash(ss:*), Bash(scripts/preflight.sh), Read, Write, Edit
---
# Phase 1 — Environment Discovery

**Read-only.** If a command you are about to run would change state, do not run it.

Run each through `scripts/capture.sh 1 <slug> -- <cmd>` so the evidence lands in `logs/`:

```
uname -a; cat /etc/os-release
nproc; free -h; df -h /
which docker git curl
docker --version; docker compose version
id -nG "$USER"
ss -lntp | grep -E ':(80|443|5432|6379|5672|9200)\b'
scripts/preflight.sh
```

Write `docs/01-environment-discovery.md`: findings table, then an explicit **gap list**.

Known deltas from the spec's assumptions — confirm each with evidence, do not just repeat them:
- Docker and Compose v2 are already installed and the user is in the `docker` group, so spec
  Phase 3 task 1 is a *verification*, not an install.
- Port 80 is free; 443/9200/8081/15672 are held by the `docker_magento` stack. No collision.
- **RAM is the binding risk**, not ports. State it as a risk here, before Phase 3, not after.

## Before doing anything
1. Read `specs/STATE.md`. If the phase it names is earlier than this one, or the previous phase is
   not marked complete, **stop** and say which gate is unmet. Do not do the work anyway.
2. Read `CLAUDE.md`. The STOP-AND-ASK list applies with no standing grants.

## Before finishing
1. Rewrite `specs/STATE.md` with the new phase, last completed task, next task, blockers, open
   approvals, validation tally, and any outstanding `UNVERIFIED:` items.
2. Append a dated entry to `CHANGELOG.md`: what changed, why, validation result.
3. Print `Safe to /compact.`
