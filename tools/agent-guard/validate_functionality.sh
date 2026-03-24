#!/usr/bin/env bash
set -euo pipefail

ROOT="$(/usr/bin/git rev-parse --show-toplevel)"
OUT_DIR="$ROOT/.agent/guard"
OUT_FILE="$OUT_DIR/last_validation.env"
LOG_FILE="$OUT_DIR/last_validation.log"
mkdir -p "$OUT_DIR"

{
  echo "== Validation started at $(date -u '+%Y-%m-%dT%H:%M:%SZ') =="
  echo "+ swift build"
  swift build
  echo "+ swift test"
  swift test
  echo "== Validation PASS =="
} >"$LOG_FILE" 2>&1

epoch="$(date +%s)"
{
  echo "status=PASS"
  echo "epoch=$epoch"
  echo "checks=swift_build,swift_test"
  echo "log_file=$LOG_FILE"
} >"$OUT_FILE"

echo "Validation PASS. Report: $OUT_FILE"
