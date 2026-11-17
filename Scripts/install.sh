#!/bin/bash
# Builds a Release copy of Graphitree and installs it as /Applications/Graphitree.app.
#
# It never interrupts a running Graphitree: if one is open, the new build waits in build.noindex
# until Graphitree is quit, unless --restart or --launch is passed. It only opens Graphitree with
# --launch, so a script or an AI tool running this never takes the screen.
#
# Usage:
#   Scripts/install.sh                  build and install
#   Scripts/install.sh --restart        quit a running Graphitree to install over it
#   Scripts/install.sh --launch         the same, then open the new copy
#   Scripts/install.sh --sign-locally   sign for this Mac only, without an Apple team
#   DEVELOPMENT_TEAM=<team ID> Scripts/install.sh   sign with your own Apple team
#
# Needs Xcode (the app, not only its command line tools) and XcodeGen (`brew install xcodegen`).
# To uninstall: Graphitree › Uninstall Graphitree…, or `graphitree uninstall`.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")/.."

RESTART=0
LAUNCH=0
SIGN_LOCALLY=0
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=1 ;;
    --launch) RESTART=1; LAUNCH=1 ;;
    --sign-locally) SIGN_LOCALLY=1 ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg. See Scripts/install.sh --help." >&2; exit 2 ;;
  esac
done

APP="/Applications/Graphitree.app"
DERIVED="$PWD/build.noindex"
BUILT="$DERIVED/Build/Products/Release/Graphitree.app"
LOG="$DERIVED/install.log"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Graphitree builds with Xcode. Install it from the App Store, open it once, then run:" >&2
  echo "  sudo xcode-select --switch /Applications/Xcode.app" >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null; then
  echo "Graphitree's Xcode project is made by XcodeGen. Install it with: brew install xcodegen" >&2
  exit 1
fi

# project.yml signs with the owner's free team. Anyone else signs with their own team, or for
# this Mac only. A copy signed for this Mac only asks again for Keychain and Documents access
# after each new build.
SIGNING=()
if [[ $SIGN_LOCALLY -eq 1 ]]; then
  SIGNING=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
elif [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  SIGNING=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

mkdir -p "$DERIVED"
xcodegen generate --quiet
echo "Building Graphitree (Release). Log: $LOG"
# ${SIGNING[@]+...}: an empty array is "unbound" to macOS's bash 3.2 under set -u.
if ! xcodebuild -project Graphitree.xcodeproj -scheme Graphitree -configuration Release \
    -destination 'platform=macOS' -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
    ${SIGNING[@]+"${SIGNING[@]}"} build >"$LOG" 2>&1; then
  grep -E 'error:|BUILD FAILED' "$LOG" | sort -u | tail -20 >&2
  if grep -qE 'No Account for Team|No signing certificate|requires a development team|No profiles for' "$LOG"; then
    echo >&2
    echo "Signing failed: this Mac isn't signed in to the project's Apple team. Run it again with" >&2
    echo "--sign-locally, or with DEVELOPMENT_TEAM=<your team ID> in front." >&2
  fi
  exit 1
fi
[[ -d "$BUILT" ]] || { echo "The build finished, but $BUILT isn't there. See $LOG." >&2; exit 1; }
codesign --verify --deep --strict "$BUILT"

if pgrep -x Graphitree >/dev/null; then
  if [[ $RESTART -eq 0 ]]; then
    echo "Graphitree is open, so it wasn't replaced. Quit it and run this again, or pass --restart."
    exit 0
  fi
  /usr/bin/osascript -e 'tell application id "com.marcuslai.Graphitree" to quit' 2>/dev/null || true
  for _ in {1..20}; do pgrep -x Graphitree >/dev/null || break; sleep 0.5; done
  if pgrep -x Graphitree >/dev/null; then
    echo "Graphitree didn't quit, so it wasn't replaced. Quit it and run this again." >&2
    exit 1
  fi
fi

rm -rf "$APP"
ditto "$BUILT" "$APP"
echo "Installed $APP"
if [[ $LAUNCH -eq 1 ]]; then
  open "$APP"
  echo "Opened Graphitree"
fi
