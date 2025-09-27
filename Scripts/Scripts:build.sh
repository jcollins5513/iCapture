#!/usr/bin/env bash
set -euo pipefail
SCHEME="iCapture"
CONFIG="Debug"
DESTINATION="generic/platform=iOS"

xcodebuild \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "$DESTINATION" \
  -sdk iphoneos \
  -quiet build