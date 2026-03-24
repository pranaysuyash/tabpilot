#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <pathspec> [<pathspec> ...]"
  echo "Example: $0 Sources/ChromeTabManager Docs Artifacts"
  exit 1
fi

# 1) No deleted or renamed files in scoped paths
if git diff --name-status -- "$@" | awk '$1=="D" || $1=="R" {exit 1}'; then
  :
else
  echo "FAIL: additive-only policy violated in scoped paths (deleted/renamed file):"
  git diff --name-status -- "$@" | awk '$1=="D" || $1=="R" {print "  " $0}'
  exit 1
fi

# 2) No removed lines in scoped paths
VIOLATIONS=$(git diff --numstat -- "$@" | awk '$2 ~ /^[0-9]+$/ && $2 > 0 {print}')
if [[ -n "$VIOLATIONS" ]]; then
  echo "FAIL: additive-only policy violated in scoped paths (removed lines):"
  echo "$VIOLATIONS" | sed 's/^/  /'
  exit 1
fi

echo "PASS: additive-only scoped diff audit"
