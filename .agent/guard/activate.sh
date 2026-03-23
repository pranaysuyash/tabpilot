#!/usr/bin/env bash
ROOT="/Users/pranay/Projects/chrome-tab-manager-swift"
export PATH="$ROOT/.agent/bin:$PATH"
export AGENT_GUARD_VALIDATION_FILE="$ROOT/.agent/guard/last_validation.env"
export AGENT_GUARD_MAX_AGE_SEC="${AGENT_GUARD_MAX_AGE_SEC:-1800}"
echo "Agent guard active: git is staging-only, rm requires fresh validation."
