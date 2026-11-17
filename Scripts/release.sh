#!/bin/bash
# Publishes a Graphitree release on GitHub. Every copy then sees it in Graphitree › Check for
# Updates… (and its daily check), and new people download it from the releases page.
#
# It makes the disk image with Scripts/package.sh and signs it with Graphitree's update key, which
# is in this Mac's login Keychain under the account "graphitree". It writes the update feed,
# appcast.xml, then shows what it will publish and asks. Only on a yes does it create the GitHub
# release v<version> with the disk image and the feed. The release goes to the repo in project.yml's
# SUFeedURL, the one every copy checks, as that repo's owner.
#
# Before it: put the new version in MARKETING_VERSION in project.yml, write what's new in a Markdown
# file, and commit and push. The release is tagged at the pushed commit.
#
# Usage:
#   Scripts/release.sh --notes <file.md>             publish, after asking
#   Scripts/release.sh --notes <file.md> --dry-run   make it all in dist/ and publish nothing
#   ... --key-file <file>                            sign with an exported key, not the Keychain's
#
# The first time it signs, the Keychain asks whether sign_update may use the key: Always Allow.
# Needs the GitHub CLI (`brew install gh`), signed in as the repo's owner (`gh auth login`).
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")/.."

NOTES=""
DRY_RUN=0
KEY_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notes) NOTES="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --key-file) KEY_FILE="${2:-}"; shift 2 ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "Unknown option: $1. See Scripts/release.sh --help." >&2; exit 2 ;;
  esac
done

fail() { echo "$1" >&2; exit 1; }

[[ -n "$NOTES" && -f "$NOTES" ]] || fail "Say what's new in a Markdown file and pass it with --notes <file>. It's shown in the update window and on the release page."
! grep -q ']]>' "$NOTES" || fail "The notes can't contain ]]>."

# Where every copy looks for updates, so where the release has to go.
FEED=$(sed -n 's/^ *SUFeedURL: *//p' project.yml)
[[ "$FEED" =~ ^https://github\.com/([^/]+)/([^/]+)/releases/latest/download/appcast\.xml$ ]] \
  || fail "project.yml's SUFeedURL isn't a GitHub releases feed: $FEED"
OWNER="${BASH_REMATCH[1]}"
REPO="$OWNER/${BASH_REMATCH[2]}"
VERSION=$(sed -n 's/^ *MARKETING_VERSION: *//p' project.yml)
TAG="v$VERSION"

# The repo owner's GitHub account, whichever account `gh` has active.
gh_owner() { GH_TOKEN="$GH_OWNER_TOKEN" gh "$@"; }
if [[ $DRY_RUN -eq 0 ]]; then
  command -v gh >/dev/null || fail "Publishing needs the GitHub CLI: brew install gh"
  GH_OWNER_TOKEN=$(gh auth token --user "$OWNER" 2>/dev/null) || fail "The GitHub CLI isn't signed in as $OWNER, who owns $REPO. Run: gh auth login"
  [[ -z "$(git status --porcelain)" ]] || fail "There are uncommitted changes. Commit and push them first: the release is tagged at the pushed commit."
  git fetch --quiet origin
  UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || fail "This branch doesn't track a branch on GitHub. Push it first."
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse "$UPSTREAM")" ]] || fail "This commit isn't the one on GitHub ($UPSTREAM). Push or pull first."
  [[ "$(gh_owner repo view "$REPO" --json visibility -q .visibility)" == "PUBLIC" ]] \
    || fail "$REPO is private, so copies of Graphitree can't read its updates. Make it public first."
  ! gh_owner release view "$TAG" --repo "$REPO" >/dev/null 2>&1 || fail "$REPO already has $TAG. Put a new version in MARKETING_VERSION in project.yml."
  LATEST=$(gh_owner release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null || true)
  if [[ -n "$LATEST" ]]; then
    NEWEST=$(printf '%s\n%s\n' "${LATEST#v}" "$VERSION" | sort -V | tail -1)
    [[ "$NEWEST" == "$VERSION" ]] || fail "$VERSION is older than the latest release, $LATEST, so no copy would update to it."
  fi
fi

Scripts/package.sh
DIST="$PWD/dist"
DMG="$DIST/Graphitree-$VERSION.dmg"
APP="$PWD/build.noindex/package/Build/Products/Release/Graphitree.app"
[[ -f "$DMG" ]] || fail "Scripts/package.sh didn't make $DMG. Is MARKETING_VERSION the version it built?"
MINIMUM=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP/Contents/Info.plist")
[[ "$MINIMUM" == *.*.* ]] || MINIMUM="$MINIMUM.0"

# Sparkle installs an update only when this signature checks out against the key in the app.
TOOLS="$PWD/build.noindex/package/SourcePackages/artifacts/sparkle/Sparkle/bin"
[[ -x "$TOOLS/sign_update" ]] || fail "Sparkle's sign_update isn't in $TOOLS."
if [[ -n "$KEY_FILE" ]]; then
  echo "Signing the update with the key in $KEY_FILE."
  SIGNATURE=$("$TOOLS/sign_update" --ed-key-file "$KEY_FILE" -p "$DMG") || fail "Signing with $KEY_FILE failed."
else
  echo "Signing the update with the key \"graphitree\" in your login Keychain."
  SIGNATURE=$("$TOOLS/sign_update" --account graphitree -p "$DMG") || fail "Signing failed. Is the key in this Mac's login Keychain? See README › Make the download."
fi
# The same check Sparkle makes, with the public key inside the app being released.
APP_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$APP/Contents/Info.plist")
CHECK=$(mktemp "${TMPDIR:-/tmp}/graphitree-signature.XXXXXX")
mv "$CHECK" "$CHECK.swift"
cat > "$CHECK.swift" <<'SWIFT'
import CryptoKit
import Foundation
let arguments = CommandLine.arguments
guard arguments.count == 4, let key = Data(base64Encoded: arguments[1]), let signature = Data(base64Encoded: arguments[2]),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
      let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[3]), options: .mappedIfSafe) else { exit(2) }
exit(publicKey.isValidSignature(signature, for: data) ? 0 : 1)
SWIFT
VALID=0
swift "$CHECK.swift" "$APP_KEY" "$SIGNATURE" "$DMG" || VALID=$?
rm -f "$CHECK.swift"
[[ $VALID -eq 0 ]] || fail "The signature doesn't match the update key inside the app (SUPublicEDKey in project.yml), so no copy would install it. Sign with the key that matches."
LENGTH=$(stat -f %z "$DMG")

DOWNLOAD="https://github.com/$REPO/releases/download/$TAG/$(basename "$DMG")"
PAGE="https://github.com/$REPO/releases/tag/$TAG"
FEED_FILE="$DIST/appcast.xml"
# Only the newest version: Sparkle offers it to every older copy.
cat > "$FEED_FILE" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Graphitree</title>
    <link>https://github.com/$REPO/releases</link>
    <item>
      <title>Graphitree $VERSION</title>
      <link>$PAGE</link>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MINIMUM</sparkle:minimumSystemVersion>
      <description sparkle:format="markdown"><![CDATA[
$(cat "$NOTES")
]]></description>
      <enclosure url="$DOWNLOAD" sparkle:edSignature="$SIGNATURE" length="$LENGTH" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
xmllint --noout "$FEED_FILE" || fail "The update feed isn't valid XML."

# The release page: what's new, then how to install it for the first time.
PAGE_NOTES="$DIST/release-notes.md"
{
  cat "$NOTES"
  echo
  echo "---"
  echo
  echo "**New to Graphitree?** Download $(basename "$DMG") below, drag Graphitree to Applications, then follow [Install](https://github.com/$REPO#download): macOS asks you to allow it once, in System Settings › Privacy & Security."
  echo
  echo "**Already have it?** Choose Graphitree › Check for Updates…"
} > "$PAGE_NOTES"

echo
echo "Ready: Graphitree $VERSION for $REPO, tagged $TAG."
echo "  $DMG ($LENGTH bytes), signed for updates"
echo "  $FEED_FILE"
echo "  Release page text: $PAGE_NOTES"
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run: nothing was published."
  exit 0
fi
read -r -p "Publish $TAG to $REPO? Every copy of Graphitree will be offered it. [y/N] " answer
[[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || { echo "Nothing was published."; exit 0; }

gh_owner release create "$TAG" "$DMG" "$DMG.sha256" "$FEED_FILE" --repo "$REPO" \
  --target "$(git rev-parse HEAD)" --title "Graphitree $VERSION" --notes-file "$PAGE_NOTES" --latest
# What copies of Graphitree will read: the newest release's feed.
for _ in 1 2 3 4 5 6; do
  if curl -fsSL "$FEED" 2>/dev/null | grep -q "<sparkle:version>$VERSION</sparkle:version>"; then
    echo "Published $PAGE. The update feed now offers $VERSION."
    exit 0
  fi
  sleep 5
done
fail "Published $PAGE, but $FEED doesn't offer $VERSION yet. Check the release has appcast.xml."
