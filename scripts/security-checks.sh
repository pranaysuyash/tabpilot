#!/usr/bin/env bash
set -euo pipefail

echo "==> Running security-focused test suite"
swift test --filter SecurityTests

echo "==> Running lightweight secret scan"
if rg --line-number --color=never \
  --glob '!Tests/**' \
  --glob '!Docs/**' \
  --glob '!Artifacts/**' \
  '(BEGIN (RSA|EC|OPENSSH) PRIVATE KEY|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_\-]{35})' \
  Sources scripts .github; then
  echo "Potential hardcoded secret material detected."
  exit 1
fi

echo "==> Running supply-chain security checks"
./scripts/supply-chain-check.sh

echo "Security checks completed successfully."
