#!/bin/bash
# Builds the checks target and runs the fixture checks.
# Usage: Scripts/test.sh
#        Scripts/test.sh --real ~/Documents/GitHub/graphify-out
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")/.."

xcodegen generate >/dev/null
xcodebuild -project Graphitree.xcodeproj -scheme GraphitreeChecks -configuration Debug \
  -allowProvisioningUpdates -derivedDataPath build.noindex build | tail -2 >&2
build.noindex/Build/Products/Debug/GraphitreeChecks "$@"
