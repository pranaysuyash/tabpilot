#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="Artifacts/forensics"
mkdir -p "$OUT_DIR"
OUT_JSON="$OUT_DIR/opencode_session_inventory.json"
OUT_MD="$OUT_DIR/opencode_session_inventory.md"

GLOB="$HOME/Library/Application Support/ai.opencode.desktop/opencode.global.dat"
WS1="$HOME/Library/Application Support/ai.opencode.desktop/opencode.workspace.L1VzZXJzL3By.1h6txon.dat"
WS2="$HOME/Library/Application Support/ai.opencode.desktop/opencode.workspace.-Users-prana.eqwgy8.dat"
PROJ_ENC="L1VzZXJzL3ByYW5heS9Qcm9qZWN0cy9jaHJvbWUtdGFiLW1hbmFnZXItc3dpZnQ/"

if [[ ! -f "$GLOB" ]]; then
  echo "FAIL: missing $GLOB"
  exit 1
fi

jq -r --arg p "$PROJ_ENC" '
  .layout
  | fromjson
  | .sessionView
  | to_entries
  | map(select(.key|startswith($p)))
  | map({
      key: .key,
      session_id: (.key|split("/")|last),
      review_open_count: ((.value.reviewOpen // []) | length),
      review_open: (.value.reviewOpen // [])
    })
' "$GLOB" > "$OUT_JSON"

{
  echo "# OpenCode Session Inventory (chrome-tab-manager-swift)"
  echo
  echo "Generated: $(date)"
  echo
  jq -r '.[] | "- " + .session_id + ": reviewOpen=" + (.review_open_count|tostring)' "$OUT_JSON"
} > "$OUT_MD"

# Optional: capture workspace session prompt/comment keys inventory (metadata only)
if [[ -f "$WS1" ]]; then
  jq -r 'to_entries[] | select(.key|startswith("session:")) | .key' "$WS1" | sort > "$OUT_DIR/workspace_session_keys.txt"
fi
if [[ -f "$WS2" ]]; then
  jq -r 'to_entries[] | select(.key=="workspace:model-selection") | .value' "$WS2" > "$OUT_DIR/workspace_model_selection.json" || true
fi

echo "Generated: $OUT_JSON and $OUT_MD"
