#!/usr/bin/env bash
set -euo pipefail

ROOT="$(/usr/bin/git rev-parse --show-toplevel)"
mkdir -p "$ROOT/.agent/bin" "$ROOT/.agent/guard"

ln -sf "$ROOT/tools/agent-guard/git-wrapper.sh" "$ROOT/.agent/bin/git"
ln -sf "$ROOT/tools/agent-guard/rm-wrapper.sh" "$ROOT/.agent/bin/rm"

cat > "$ROOT/.agent/guard/activate.sh" <<EOF
#!/usr/bin/env bash
ROOT="$ROOT"
export PATH="\$ROOT/.agent/bin:\$PATH"
export AGENT_GUARD_VALIDATION_FILE="\$ROOT/.agent/guard/last_validation.env"
export AGENT_GUARD_MAX_AGE_SEC="\${AGENT_GUARD_MAX_AGE_SEC:-1800}"
echo "Agent guard active: git is staging-only, rm requires fresh validation."
EOF

chmod +x "$ROOT/.agent/guard/activate.sh"
echo "Installed agent guard."
echo "Run: source .agent/guard/activate.sh"
