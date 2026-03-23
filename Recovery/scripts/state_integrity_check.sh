#!/usr/bin/env bash
set -euo pipefail

BASE_PTR="Recovery/safety/LATEST"
if [[ ! -f "$BASE_PTR" ]]; then
  echo "FAIL: baseline pointer missing: $BASE_PTR"
  exit 1
fi
BASE=$(cat "$BASE_PTR")
EXPECTED="$BASE/repo/status.porcelain_v2.tracked_only.txt"
if [[ ! -f "$EXPECTED" ]]; then
  echo "FAIL: expected tracked-only baseline status missing: $EXPECTED"
  exit 1
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
git status --porcelain=v2 --untracked-files=no > "$TMP"

if diff -u "$EXPECTED" "$TMP" >/dev/null; then
  echo "PASS: working tree/index match baseline status"
else
  echo "WARN: working tree/index differ from baseline status"
  diff -u "$EXPECTED" "$TMP" || true
  exit 1
fi
