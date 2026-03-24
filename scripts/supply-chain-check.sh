#!/usr/bin/env bash
set -euo pipefail

echo "==> Supply chain: validating package manifest"
if rg --line-number --color=never 'http://|\.package\(path:' Package.swift; then
  echo "Unsafe or local package source detected in Package.swift."
  exit 1
fi

echo "==> Supply chain: resolving dependency graph"
swift package show-dependencies >/dev/null

echo "==> Supply chain: scanning CI for unpinned GitHub Actions"
if rg --line-number --color=never 'uses:\\s*[^@\\s]+@[^\\n]+' .github/workflows | rg -v '@v[0-9]+'; then
  echo "Potentially unpinned GitHub Action detected."
  exit 1
fi

echo "Supply chain checks completed successfully."
