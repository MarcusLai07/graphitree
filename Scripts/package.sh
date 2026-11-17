#!/bin/bash
# Makes the download: dist/Graphitree-<version>.dmg, holding a Release build for Apple silicon and
# Intel, signed with the project's Apple team, next to an Applications shortcut to drag it onto.
# The same disk image is what Graphitree › Check for Updates… installs (Scripts/release.sh).
#
# The team is the free Personal Team, so the build isn't notarized: macOS blocks a downloaded
# copy until the person clicks Open Anyway in Privacy & Security once (README › Install). Its
# signature names the team's Apple Development certificate, which anyone can read with codesign.
#
# It only builds and checks. It never opens Graphitree or publishes anything.
#
# Usage:
#   Scripts/package.sh                              make the disk image
#   DEVELOPMENT_TEAM=<team ID> Scripts/package.sh   sign with another Apple team
#
# Needs Xcode, XcodeGen (`brew install xcodegen`) and this Mac signed in to the Apple team.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")/.."

for arg in "$@"; do
  case "$arg" in
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg. See Scripts/package.sh --help." >&2; exit 2 ;;
  esac
done

# Its own build folder, so it never collides with Scripts/install.sh or Scripts/test.sh.
# Inside build.noindex, Spotlight doesn't index it, so its copies of the app aren't registered.
DERIVED="$PWD/build.noindex/package"
BUILT="$DERIVED/Build/Products/Release/Graphitree.app"
LOG="$DERIVED/package.log"
DIST="$PWD/dist"

fail() { echo "$1" >&2; exit 1; }

xcodebuild -version >/dev/null 2>&1 || fail "Packaging needs Xcode. Install it from the App Store, open it once, then run: sudo xcode-select --switch /Applications/Xcode.app"
command -v xcodegen >/dev/null || fail "Graphitree's Xcode project is made by XcodeGen. Install it with: brew install xcodegen"

# Without the base entitlements, the build leaves out get-task-allow, which would let other
# programs attach a debugger to Graphitree and read what it holds, such as AI keys. Without
# required entitlements, the command line tool isn't given an application identifier, which
# macOS can insist a provisioning profile allows, and which it doesn't use.
SETTINGS=(CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENTITLEMENTS_REQUIRED=NO)
[[ -n "${DEVELOPMENT_TEAM:-}" ]] && SETTINGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")

# Always a clean build: an incremental one can leave an older command line tool inside the app.
# The downloaded packages stay, in SourcePackages.
rm -rf "$DERIVED/Build"
mkdir -p "$DERIVED" "$DIST"
xcodegen generate --quiet
echo "Building Graphitree (Release, Apple silicon and Intel). Log: $LOG"
# generic/platform=macOS builds every architecture, not only this Mac's.
if ! xcodebuild -project Graphitree.xcodeproj -scheme Graphitree -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
    "${SETTINGS[@]}" build >"$LOG" 2>&1; then
  grep -E 'error:|BUILD FAILED' "$LOG" | sort -u | tail -20 >&2
  if grep -qE 'No Account for Team|No signing certificate|requires a development team|No profiles for' "$LOG"; then
    echo >&2
    echo "Signing failed: this Mac isn't signed in to the project's Apple team (Xcode › Settings ›" >&2
    echo "Accounts), or run it with DEVELOPMENT_TEAM=<your team ID> in front." >&2
  fi
  exit 1
fi
[[ -d "$BUILT" ]] || fail "The build finished, but $BUILT isn't there. See $LOG."
# Xcode registers each app it builds with Launch Services, sometimes after the build returns.
# With no Graphitree in Applications, macOS could pick this copy when something opens
# Graphitree, so it's unregistered on the way out, however the script ends.
MOUNT=""
cleanup() {
  if [[ -n "$MOUNT" ]]; then hdiutil detach -quiet "$MOUNT" 2>/dev/null; rmdir "$MOUNT" 2>/dev/null; fi
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$BUILT" 2>/dev/null || true
}
trap cleanup EXIT

# The licenses of everything third-party inside, current and in the app (Scripts/notices.py).
python3 -I Scripts/notices.py --check || exit 1
[[ -f "$BUILT/Contents/Resources/ThirdPartyNotices.txt" ]] || fail "The app doesn't include ThirdPartyNotices.txt."

# The checks a download has to pass. A copy that fails any of them is one macOS calls damaged,
# that asks for permissions again after each update, or that doesn't run on some Macs.
codesign --verify --deep --strict "$BUILT" || fail "The app's signature doesn't verify."
signature() { codesign -dvv "$1" 2>&1; }
TEAM=$(signature "$BUILT" | sed -n 's/^TeamIdentifier=//p')
SIGNER=$(signature "$BUILT" | sed -n 's/^Authority=//p' | head -1)
[[ -n "$TEAM" && "$TEAM" != "not set" ]] || fail "The app is signed for this Mac only, not with an Apple team, so downloaded copies would ask for permissions again after every update."
for exe in "$BUILT/Contents/MacOS/Graphitree" "$BUILT/Contents/MacOS/graphitree-cli" "$BUILT/Contents/Frameworks/Sparkle.framework"; do
  name=$(basename "$exe")
  [[ -e "$exe" ]] || fail "$name is missing from the app."
  [[ "$(signature "$exe" | sed -n 's/^TeamIdentifier=//p')" == "$TEAM" ]] || fail "$name isn't signed by the same team as the app."
  [[ -f "$exe" ]] || continue
  archs=" $(lipo -archs "$exe") "
  [[ "$archs" == *" arm64 "* && "$archs" == *" x86_64 "* ]] || fail "$name is built for$archs only, not for both Apple silicon and Intel."
done
# Re-signed as it's copied in, so the same code has the same code directory hash, not the same bytes.
cdhash() { codesign -dvvv "$1" 2>&1 | sed -n 's/^CDHash=//p'; }
[[ "$(cdhash "$BUILT/Contents/MacOS/graphitree-cli")" == "$(cdhash "$DERIVED/Build/Products/Release/graphitree-cli")" ]] \
  || fail "The command line tool inside the app isn't the one just built."
if codesign -d --entitlements - --xml "$BUILT/Contents/MacOS/graphitree-cli" 2>/dev/null | grep -q application-identifier; then
  fail "graphitree-cli still has an application identifier."
fi
# Every program in the app, Sparkle's helpers included.
while IFS= read -r exe; do
  if codesign -d --entitlements - --xml "$exe" 2>/dev/null | grep -q get-task-allow; then
    fail "${exe#"$BUILT/"} still has get-task-allow, which lets other programs debug it."
  fi
done < <(find "$BUILT" -type f -perm -u+x)

info() { /usr/libexec/PlistBuddy -c "Print :$1" "$BUILT/Contents/Info.plist" 2>/dev/null; }
VERSION=$(info CFBundleShortVersionString)
# Sparkle offers an update when the feed's build number is higher than this copy's.
[[ "$(info CFBundleVersion)" == "$VERSION" ]] || fail "The build number, $(info CFBundleVersion), isn't the version, $VERSION. See CURRENT_PROJECT_VERSION in project.yml."
[[ "$(info SUFeedURL)" == https://* && -n "$(info SUPublicEDKey)" ]] || fail "The app has no update feed or update key (SUFeedURL, SUPublicEDKey in project.yml)."
DMG="$DIST/Graphitree-$VERSION.dmg"
ROOT="$DERIVED/dmg-root"
rm -rf "$ROOT" "$DMG" "$DMG.sha256"
mkdir -p "$ROOT"
ditto "$BUILT" "$ROOT/Graphitree.app"
ln -s /Applications "$ROOT/Applications"
# APFS and lzfse, which Sparkle recommends for updates: quick to open and check.
hdiutil create -quiet -volname Graphitree -srcfolder "$ROOT" -fs APFS -format ULFO "$DMG"
rm -rf "$ROOT"
hdiutil verify -quiet "$DMG" || fail "The disk image doesn't verify."

# The copy in the image, as a downloader gets it: attached read-only and out of Finder's sight,
# checked, then detached. Nothing in it is opened.
MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/graphitree-dmg.XXXXXX")
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$DMG"
codesign --verify --deep --strict "$MOUNT/Graphitree.app" || fail "The app inside the disk image doesn't verify."
[[ -L "$MOUNT/Applications" ]] || fail "The disk image has no Applications shortcut."
hdiutil detach -quiet "$MOUNT"
rmdir "$MOUNT"
MOUNT=""

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Made $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '))"
echo "  Signed by $SIGNER, team $TEAM. Not notarized."
echo "  For Apple silicon and Intel, macOS $(info LSMinimumSystemVersion) or later."
echo "  SHA-256: $(cut -d' ' -f1 "$DMG.sha256")"
echo "Nothing was published. People who download it open it once with Open Anyway (README › Install)."
