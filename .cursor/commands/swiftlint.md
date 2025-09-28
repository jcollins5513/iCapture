#!/usr/bin/env bash
set -euo pipefail
if command -v swiftlint >/dev/null 2>&1; then
  swiftlint --strict
else
  echo "SwiftLint not installed" >&2
  exit 1
fi