#!/usr/bin/env bash
set -euo pipefail

# 1) No deleted or renamed files
if git diff --name-status | awk '$1=="D" || $1=="R" {exit 1}'; then
  :
else
  echo "FAIL: additive-only policy violated (deleted or renamed file detected)."
  git diff --name-status | awk '$1=="D" || $1=="R" {print "  " $0}'
  exit 1
fi

# 2) No removed lines in modified tracked files
# numstat columns: added removed path
VIOLATIONS=$(git diff --numstat | awk '$2 ~ /^[0-9]+$/ && $2 > 0 {print}')
if [[ -n "$VIOLATIONS" ]]; then
  echo "FAIL: additive-only policy violated (removed lines detected):"
  echo "$VIOLATIONS" | sed 's/^/  /'
  exit 1
fi

echo "PASS: additive-only diff audit"
