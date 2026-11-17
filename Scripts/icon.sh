#!/bin/bash
# Renders the app icon's layers from design/AppIcon/*.svg into App/Resources/AppIcon.icon, the
# Icon Composer document Xcode turns into the icon (Liquid Glass on macOS 26, flat before that).
# Layer order and glass settings live in App/Resources/AppIcon.icon/icon.json.
# Usage: Scripts/icon.sh [--preview out.png]
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
cd "$(dirname "$0")/.."

for layer in background roots nodes; do
  rsvg-convert -w 1024 -h 1024 "design/AppIcon/$layer.svg" -o "App/Resources/AppIcon.icon/Assets/$layer.png"
done

if [ "${1:-}" = "--preview" ]; then
  ictool="$(xcode-select -p)/Applications/Icon Composer.app/Contents/Executables/ictool"
  "$ictool" App/Resources/AppIcon.icon --export-image --output-file "$2" \
    --platform macOS --rendition Default --width 1024 --height 1024 --scale 1 >/dev/null
  echo "Preview: $2"
fi
