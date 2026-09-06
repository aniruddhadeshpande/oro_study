#!/usr/bin/env bash
# magento-stack.sh — stop/start the co-resident Magento learning stack. Nothing else.
#
# WHAT:  `stop` and `start` on the docker_magento compose project, by project label. Never `down`,
#        never `-v`, never `rm`. Refuses any argument it does not recognise.
# WHY:   Oro needs the RAM this stack holds (preflight.sh). Stopping containers is fully reversible
#        and touches no volume; `down -v` would destroy that environment's database. The two verbs
#        look similar in a terminal at 11pm, so this script exists to make the wrong one unreachable.
# ARCH:  Docker Compose tracks project membership by container label, so this works without the
#        original compose file being present or the working directory being right.

set -uo pipefail

PROJECT="${MAGENTO_PROJECT:-docker_magento}"
ACTION="${1:-}"

running_count() { docker ps    --filter "label=com.docker.compose.project=${PROJECT}" -q | wc -l; }
total_count()   { docker ps -a --filter "label=com.docker.compose.project=${PROJECT}" -q | wc -l; }

case "$ACTION" in
  status)
    echo "project: ${PROJECT}   running: $(running_count)   total: $(total_count)"
    docker ps -a --filter "label=com.docker.compose.project=${PROJECT}" \
      --format 'table {{.Names}}\t{{.Status}}'
    ;;
  stop)
    N="$(running_count)"
    if [ "$N" -eq 0 ]; then echo "already stopped (0 running)"; exit 0; fi
    echo "Stopping ${N} containers in project '${PROJECT}'."
    echo "Reversible: scripts/magento-stack.sh start. No volumes are touched, no data is removed."
    docker stop $(docker ps --filter "label=com.docker.compose.project=${PROJECT}" -q) >/dev/null
    echo "stopped. running now: $(running_count)"
    ;;
  start)
    N="$(total_count)"
    if [ "$N" -eq 0 ]; then echo "no containers found for project '${PROJECT}'"; exit 1; fi
    docker start $(docker ps -a --filter "label=com.docker.compose.project=${PROJECT}" -q) >/dev/null
    echo "started. running now: $(running_count)"
    ;;
  *)
    echo "usage: $0 {status|stop|start}" >&2
    echo "this script cannot down, prune, or remove anything — by design" >&2
    exit 64
    ;;
esac
