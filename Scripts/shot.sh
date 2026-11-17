#!/bin/bash
# Renders a Graphitree panel, or the whole main window, to a PNG without showing a window or taking focus.
# Usage: Scripts/shot.sh <window|firstrun|build|folders|playbook|agents|browse> <out.png> [-key value …]
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
xcodebuild -project Graphitree.xcodeproj -scheme GraphitreeShots -configuration Debug -derivedDataPath build.noindex build 2>&1 | grep -E "error:|BUILD FAILED" >&2 || true
build.noindex/Build/Products/Debug/GraphitreeShots "$@"
