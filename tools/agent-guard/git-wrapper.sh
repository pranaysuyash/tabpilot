#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
case "$cmd" in
  add|stage)
    exec /usr/bin/git "$@"
    ;;
  "")
    echo "AGENT GUARD: blocked empty git command."
    exit 126
    ;;
  *)
    echo "AGENT GUARD: blocked 'git $cmd'. Only staging is allowed (git add/stage)."
    exit 126
    ;;
esac
