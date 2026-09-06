#!/usr/bin/env bash
# preflight.sh — read-only go/no-go gate before any Oro bring-up.
#
# WHAT:  Checks Docker daemon, Compose v2, host port 80, RAM headroom, disk, and whether the
#        co-resident docker_magento stack is holding memory. Changes nothing. Exit 0 = go.
# WHY:   On this host the binding constraint is RAM, not ports (see CLAUDE.md). `docker compose up
#        install` peaks during migrations + reindex; starting it under-provisioned produces an
#        OOM-killed container that looks like an Oro bug and is not one.
# ARCH:  Oro's demo stack is db + php-fpm-app + web + ws + consumer + cron + mail. The consumer and
#        the Postgres shared_buffers are the memory-hungry pair; both are exercised by reindex.

set -uo pipefail

REQUIRED_MB="${ORO_REQUIRED_MB:-5000}"   # peak headroom for install/reindex
REQUIRED_DISK_GB="${ORO_REQUIRED_DISK_GB:-20}"
MAGENTO_PROJECT="${MAGENTO_PROJECT:-docker_magento}"
RC=0

row() { printf '%-26s %-30s %s\n' "$1" "$2" "$3"; }
fail() { RC=1; }

printf '%-26s %-30s %s\n' "CHECK" "VALUE" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------------"

# 1. Docker daemon
if docker info >/dev/null 2>&1; then
  row "docker daemon" "$(docker --version | awk '{print $3}' | tr -d ,)" "OK"
else
  row "docker daemon" "unreachable" "FAIL"; fail
fi

# 2. Compose v2 — never docker-compose v1
if CV="$(docker compose version --short 2>/dev/null)"; then
  row "compose v2" "$CV" "OK"
else
  row "compose v2" "absent" "FAIL"; fail
fi

# 3. Host port 80 — the only port oroinc/docker-demo binds (web service, published: 80)
if ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE '(^|:)80$'; then
  HOLDER="$(ss -lntp 2>/dev/null | awk '$4 ~ /(^|:)80$/ {print $NF}' | head -1)"
  row "host port 80" "in use ${HOLDER:-unknown}" "FAIL"; fail
else
  row "host port 80" "free" "OK"
fi

# 4. RAM headroom
AVAIL_MB="$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)"
if [ "$AVAIL_MB" -ge "$REQUIRED_MB" ]; then
  row "ram available" "${AVAIL_MB} MiB (need ${REQUIRED_MB})" "OK"
else
  row "ram available" "${AVAIL_MB} MiB (need ${REQUIRED_MB})" "FAIL"; fail
fi

# 5. Disk on /
DISK_GB="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
if [ "${DISK_GB:-0}" -ge "$REQUIRED_DISK_GB" ]; then
  row "disk free /" "${DISK_GB} GiB (need ${REQUIRED_DISK_GB})" "OK"
else
  row "disk free /" "${DISK_GB} GiB (need ${REQUIRED_DISK_GB})" "FAIL"; fail
fi

# 6. Co-resident Magento stack — informational, and the first lever if RAM fails above
MAGENTO_UP="$(docker ps --filter "label=com.docker.compose.project=${MAGENTO_PROJECT}" -q 2>/dev/null | wc -l)"
if [ "$MAGENTO_UP" -gt 0 ]; then
  row "${MAGENTO_PROJECT}" "${MAGENTO_UP} containers up" "NOTE"
else
  row "${MAGENTO_PROJECT}" "stopped" "OK"
fi

printf '%s\n' "----------------------------------------------------------------------------"
if [ "$RC" -eq 0 ]; then
  echo "PREFLIGHT: GO"
else
  echo "PREFLIGHT: NO-GO"
  if [ "$AVAIL_MB" -lt "$REQUIRED_MB" ] && [ "$MAGENTO_UP" -gt 0 ]; then
    echo "  Likely fix: scripts/magento-stack.sh stop  (non-destructive, frees the Magento stack's RAM)"
  fi
fi
exit "$RC"
