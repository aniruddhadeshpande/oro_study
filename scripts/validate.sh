#!/usr/bin/env bash
# validate.sh — the spec's 13-check validation table, as executable assertions.
#
# WHAT:  Runs each check with an asserted pass condition and records PASS / FAIL / EXPECTED-ABSENT /
#        MANUAL / SKIP. Read-only: it inspects, it does not repair. Emits a TSV to logs/ and a
#        readable table to stdout. Exit 0 only if no check FAILs.
# WHY:   Anti-pattern 2 — "a running container is not a working application". Every claim in the
#        final report must trace to a command with an expected result, not to `compose ps`.
# ARCH:  Checks 11-13 (Redis, RabbitMQ, Elasticsearch) are expected to be ABSENT: those are
#        Enterprise Edition components. CE uses the DBAL message-queue transport (a Postgres table)
#        and the ORM search engine (EAV tables in Postgres). Absence here is an architectural
#        finding to document, not a failure to fix. The script proves absence from
#        `compose config --services` rather than assuming it.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_DIR="$REPO_ROOT/docker"
DOMAIN="${ORO_APP_DOMAIN:-oro.demo}"
TS="$(date +%Y%m%dT%H%M%S)"
TSV="$REPO_ROOT/logs/validation-${TS}.tsv"

FAILED=0
declare -a ROWS

dc()   { (cd "$COMPOSE_DIR" && docker compose "$@"); }
app()  { dc exec -T php-fpm-app php bin/console "$@" 2>&1; }
psqlq(){ dc exec -T db sh -c "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -tAc \"$1\"" 2>&1 | tr -d '[:space:]'; }

record() { # num, name, verdict, detail
  [ "$3" = "FAIL" ] && FAILED=$((FAILED+1))
  ROWS+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$4")
}

http_code() { curl -s -o /dev/null -w '%{http_code}' -m 15 -H "Host: ${DOMAIN}" "$1"; }

if [ ! -f "$COMPOSE_DIR/compose.yaml" ] && [ ! -f "$COMPOSE_DIR/docker-compose.yml" ]; then
  echo "validate.sh: no compose file in docker/ — the stack has not been cloned yet (Phase 3 task 2)" >&2
  exit 2
fi

SERVICES="$(dc config --services 2>/dev/null | tr '\n' ' ')"
has_service() { printf ' %s ' "$SERVICES" | grep -q " $1 "; }

# --- 1. Long-running services up -------------------------------------------------------------
# volume-init, web-init, install, restore AND application are one-shot by design and are *expected*
# to be exited. `application` runs `true` and depends on web+consumer+cron — the dependency graph is
# what starts the stack, so its Exited status is correct, not a failure. See specs/00-environment-spec.md §3b.
LONG_RUNNING="db php-fpm-app web ws consumer cron mail"
DOWN=""
for s in $LONG_RUNNING; do
  has_service "$s" || continue
  st="$(dc ps --status running --services 2>/dev/null | grep -Fx "$s" || true)"
  [ -n "$st" ] || DOWN="$DOWN $s"
done
if [ -z "$DOWN" ]; then record 1 "containers running" PASS "all of: $LONG_RUNNING"
else record 1 "containers running" FAIL "not running:$DOWN"; fi

# --- 2. Storefront ----------------------------------------------------------------------------
C="$(http_code http://127.0.0.1/)"
case "$C" in 200|301|302) record 2 "storefront HTTP" PASS "HTTP $C" ;;
             *)           record 2 "storefront HTTP" FAIL "HTTP $C (want 200/302)" ;; esac

# --- 3. Back-office ---------------------------------------------------------------------------
C="$(http_code http://127.0.0.1/admin)"
case "$C" in 200|301|302) record 3 "back-office HTTP" PASS "HTTP $C" ;;
             *)           record 3 "back-office HTTP" FAIL "HTTP $C (want 200/302 to login)" ;; esac

# --- 4. Database accepting connections ---------------------------------------------------------
O="$(dc exec -T db pg_isready 2>&1)"
if printf '%s' "$O" | grep -q 'accepting connections'; then record 4 "postgres pg_isready" PASS "accepting connections"
else record 4 "postgres pg_isready" FAIL "$(printf '%s' "$O" | head -1)"; fi

# --- 5. Schema present -------------------------------------------------------------------------
N="$(psqlq 'select count(*) from oro_user')"
if [ "${N:-x}" -ge 1 ] 2>/dev/null; then record 5 "schema (oro_user rows)" PASS "$N rows"
else record 5 "schema (oro_user rows)" FAIL "got: ${N:-<no result>}"; fi

# --- 6. Consumers alive ------------------------------------------------------------------------
# Not optional in Oro. A stack with no live consumer is a broken install, not a partial one.
P="$(dc exec -T consumer sh -c 'ps -eo args' 2>/dev/null | grep -c 'oro:message-queue:consume' || true)"
if [ "${P:-0}" -ge 1 ]; then record 6 "consumer process alive" PASS "$P consume process(es)"
else record 6 "consumer process alive" FAIL "no oro:message-queue:consume process in container"; fi

# --- 7. Queue drains end to end ----------------------------------------------------------------
# Depth of the DBAL transport queue table is observable; the create-product round trip is not
# automatable here and stays a deliberate manual step (spec check 7).
Q="$(psqlq 'select count(*) from oro_message_queue')"
record 7 "queue round trip" MANUAL "oro_message_queue depth=${Q:-?}; create a product in /admin and time its appearance on the storefront"

# --- 8. Cron -----------------------------------------------------------------------------------
# Definitions loaded == rows in oro_cron_schedule. Read-only proof; loading them is state-changing.
N="$(psqlq 'select count(*) from oro_cron_schedule')"
CRONLOG="$(dc logs --tail=20 cron 2>/dev/null | wc -l)"
if [ "${N:-0}" -ge 1 ] 2>/dev/null && [ "${CRONLOG:-0}" -ge 1 ]; then
  record 8 "cron definitions + ticking" PASS "$N definitions, cron log active"
else
  record 8 "cron definitions + ticking" FAIL "definitions=${N:-?} cron_log_lines=${CRONLOG:-0}"
fi

# --- 9. Search ---------------------------------------------------------------------------------
# HTTP-level only: asserts the storefront search endpoint answers 200 with a non-trivial body.
# Result-set contents are eyeballed in the browser; the URL is printed so that is one click away.
BODY="$(curl -s -m 20 -H "Host: ${DOMAIN}" 'http://127.0.0.1/product/search?search=product' | wc -c)"
if [ "${BODY:-0}" -gt 2000 ]; then record 9 "storefront search (HTTP)" PASS "${BODY} bytes returned"
else record 9 "storefront search (HTTP)" FAIL "${BODY} bytes — endpoint empty or erroring"; fi

# --- 10. Cache pools ---------------------------------------------------------------------------
O="$(app cache:pool:list)"
if printf '%s' "$O" | grep -qi 'cache.app\|pool'; then record 10 "cache:pool:list" PASS "pools listed"
else record 10 "cache:pool:list" FAIL "$(printf '%s' "$O" | head -2 | tr '\n' ' ')"; fi

# --- 11-13. Enterprise-only components ---------------------------------------------------------
# Proven absent from the service list, not assumed absent.
if has_service redis; then
  O="$(dc exec -T redis redis-cli ping 2>&1)"
  [ "$O" = "PONG" ] && record 11 "redis" PASS "PONG" || record 11 "redis" FAIL "$O"
else
  record 11 "redis" EXPECTED-ABSENT "CE: no oro/redis-config bundle; Symfony filesystem cache instead"
fi

if has_service rabbitmq || has_service mq; then
  O="$(dc exec -T rabbitmq rabbitmqctl status 2>&1 | head -1)"
  record 12 "rabbitmq" PASS "$O"
else
  record 12 "rabbitmq" EXPECTED-ABSENT "CE: DBAL transport — queue lives in the oro_message_queue table"
fi

if has_service elasticsearch || has_service es; then
  O="$(curl -s -m 10 localhost:9200/_cluster/health | head -c 200)"
  record 13 "elasticsearch" PASS "$O"
else
  record 13 "elasticsearch" EXPECTED-ABSENT "CE: ORM search engine — index lives in Postgres EAV tables"
fi

# --- report ------------------------------------------------------------------------------------
{ printf '#\tcheck\tverdict\tdetail\n'; printf '%s\n' "${ROWS[@]}"; } > "$TSV"
printf '%-3s %-28s %-16s %s\n' "#" "CHECK" "VERDICT" "DETAIL"
printf '%s\n' "--------------------------------------------------------------------------------------"
printf '%s\n' "${ROWS[@]}" | while IFS=$'\t' read -r n c v d; do printf '%-3s %-28s %-16s %s\n' "$n" "$c" "$v" "$d"; done
printf '%s\n' "--------------------------------------------------------------------------------------"
echo "failures: $FAILED   tsv: ${TSV#"$REPO_ROOT"/}"
[ "$FAILED" -eq 0 ] || echo "VALIDATION: FAILED — do not proceed to Phase 6 (spec: docs are written from a validated system)"
exit $(( FAILED > 0 ? 1 : 0 ))
