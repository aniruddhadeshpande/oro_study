#!/usr/bin/env bash
# capture.sh — run a command, keep its output as redacted evidence.
#
# WHAT:  Runs a command, tees combined stdout+stderr to logs/raw/ (gitignored), applies a
#        credential-redaction pass, and writes the result to logs/<phase>-<task>-<ts>.log.
#        Exits with the wrapped command's exit code, so it is transparent in a pipeline.
# WHY:   Prime directive 7 (no secrets in artefacts) and spec Phase 5 (evidence is a deliverable).
#        Making evidence a by-product of running the command is the only way it actually gets kept.
# ARCH:  Oro's compose stack injects DB credentials and app secrets as env vars that surface in
#        install logs and `compose config` output. Redaction is not optional here, it is routine.
#
# Usage: scripts/capture.sh <phase> <task-slug> -- <command> [args...]
#        <producer> | scripts/capture.sh <phase> <task-slug> --stdin

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
RAW_DIR="$LOG_DIR/raw"

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}"; exit 64; }

[ $# -ge 3 ] || usage
PHASE="$1"; TASK="$2"; shift 2

case "$1" in
  --)      shift; MODE="exec" ;;
  --stdin) MODE="stdin" ;;
  *)       usage ;;
esac
[ "$MODE" = "stdin" ] || [ $# -ge 1 ] || usage

mkdir -p "$RAW_DIR"
TS="$(date +%Y%m%dT%H%M%S)"
SLUG="$(printf '%s' "phase${PHASE}-${TASK}" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/-\+$//')"
RAW="$RAW_DIR/${SLUG}-${TS}.raw"
OUT="$LOG_DIR/${SLUG}-${TS}.log"

# Redaction. GNU sed, case-insensitive via the I flag.
#   1. key=value / key: value for anything credential-shaped (matches POSTGRES_PASSWORD, api-key, ...)
#   2. userinfo in a DSN: scheme://user:pass@host  (Oro's ORO_DB_DSN, ORO_MQ_DSN, redis:// ...)
#   3. Authorization header values
redact() {
  sed -E \
    -e 's/((password|passwd|pwd|secret|token|apikey|api_key|api-key|access_key|private_key|auth_token|credential)[[:space:]]*[=:][[:space:]]*"?)[^[:space:]"'"'"']+/\1[REDACTED]/gI' \
    -e 's#([A-Za-z][A-Za-z0-9+.-]*://[^:/@[:space:]]+):[^@[:space:]]+@#\1:[REDACTED]@#g' \
    -e 's/(Bearer|Basic)[[:space:]]+[A-Za-z0-9._~+/=-]{8,}/\1 [REDACTED]/gI'
}

{
  echo "# capture.sh  phase=$PHASE  task=$TASK  utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# host=$(hostname)  cwd=$REPO_ROOT"
} > "$RAW"

if [ "$MODE" = "stdin" ]; then
  echo "# source: stdin" >> "$RAW"
  echo >> "$RAW"
  cat >> "$RAW"
  RC=0
else
  { echo "# command: $*"; echo; } >> "$RAW"
  "$@" >> "$RAW" 2>&1
  RC=$?
fi

echo >> "$RAW"
echo "# exit_code=$RC" >> "$RAW"

redact < "$RAW" > "$OUT"

# Fail loudly rather than emit an unredacted artefact if sed ever misbehaves.
if [ ! -s "$OUT" ] && [ -s "$RAW" ]; then
  echo "capture.sh: redaction produced an empty log; refusing to keep it" >&2
  rm -f "$OUT"
  exit 70
fi

echo "captured -> ${OUT#"$REPO_ROOT"/}  (exit $RC)" >&2
exit "$RC"
