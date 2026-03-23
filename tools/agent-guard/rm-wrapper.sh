#!/usr/bin/env bash
set -euo pipefail

ROOT="$(/usr/bin/git rev-parse --show-toplevel 2>/dev/null || pwd)"
VALIDATION_FILE="${AGENT_GUARD_VALIDATION_FILE:-$ROOT/.agent/guard/last_validation.env}"
MAX_AGE="${AGENT_GUARD_MAX_AGE_SEC:-1800}"

if [[ ! -f "$VALIDATION_FILE" ]]; then
  echo "AGENT GUARD: rm blocked. No validation report found at: $VALIDATION_FILE"
  echo "Run ./tools/agent-guard/validate_functionality.sh first."
  exit 126
fi

status="$(grep -E '^status=' "$VALIDATION_FILE" | tail -n1 | cut -d= -f2- || true)"
epoch="$(grep -E '^epoch=' "$VALIDATION_FILE" | tail -n1 | cut -d= -f2- || true)"

if [[ "$status" != "PASS" || -z "$epoch" ]]; then
  echo "AGENT GUARD: rm blocked. Validation status is not PASS."
  exit 126
fi

now="$(date +%s)"
age="$((now - epoch))"
if (( age > MAX_AGE )); then
  echo "AGENT GUARD: rm blocked. Validation is stale (${age}s old, max ${MAX_AGE}s)."
  echo "Run ./tools/agent-guard/validate_functionality.sh again."
  exit 126
fi

exec /bin/rm "$@"
