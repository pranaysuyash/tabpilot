#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  tools/recovery-scripts/policy_diff_audit_scoped.sh "$@"
else
  tools/recovery-scripts/policy_diff_audit.sh
fi

tools/recovery-scripts/state_integrity_check.sh
swift build
swift test

echo "PASS: recovery wave verification complete"
