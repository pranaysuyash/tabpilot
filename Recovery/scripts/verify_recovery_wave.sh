#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  Recovery/scripts/policy_diff_audit_scoped.sh "$@"
else
  Recovery/scripts/policy_diff_audit.sh
fi

Recovery/scripts/state_integrity_check.sh
swift build
swift test

echo "PASS: recovery wave verification complete"
