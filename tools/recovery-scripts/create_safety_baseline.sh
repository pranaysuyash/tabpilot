#!/usr/bin/env bash
set -euo pipefail

TS="${1:-$(date +%Y%m%d-%H%M%S)}"
BASE="Artifacts/safety/$TS"
mkdir -p "$BASE/repo" "$BASE/opencode"
printf "%s\n" "$BASE" > Artifacts/safety/LATEST

# Repo metadata and patch snapshots
git rev-parse HEAD > "$BASE/repo/head.sha"
git rev-parse --abbrev-ref HEAD > "$BASE/repo/branch.txt"
git status --porcelain=v2 > "$BASE/repo/status.porcelain_v2.txt"
git status --porcelain=v2 --untracked-files=no > "$BASE/repo/status.porcelain_v2.tracked_only.txt"
git status > "$BASE/repo/status.txt"
git diff --cached --binary > "$BASE/repo/staged.patch"
git diff --binary > "$BASE/repo/unstaged.patch"
git bundle create "$BASE/repo/repo.bundle" --all
cp .git/index "$BASE/repo/index.snapshot"
cp -R .git/refs "$BASE/repo/refs.snapshot"

# Tree listing for quick auditing
find Sources Tests Docs -type f | sort > "$BASE/repo/tree-files.txt" || true

# OpenCode metadata snapshot (safe copy)
OP="$HOME/Library/Application Support/ai.opencode.desktop"
if [[ -d "$OP" ]]; then
  cp "$OP/opencode.global.dat" "$BASE/opencode/opencode.global.dat" 2>/dev/null || true
  cp "$OP/opencode.workspace.L1VzZXJzL3By.1h6txon.dat" "$BASE/opencode/opencode.workspace.L1VzZXJzL3By.1h6txon.dat" 2>/dev/null || true
  cp "$OP/opencode.workspace.-Users-prana.eqwgy8.dat" "$BASE/opencode/opencode.workspace.-Users-prana.eqwgy8.dat" 2>/dev/null || true
fi
printf "Safety baseline created: %s\n" "$BASE"
