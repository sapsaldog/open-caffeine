#!/usr/bin/env bash
#
# Build a release, sign it with Developer ID, have Apple notarize it, then zip it,
# EdDSA-sign the zip, and (re)generate the Sparkle appcast. Afterwards upload the
# zip to a GitHub release and commit appcast.xml —
# raw.githubusercontent.com/.../appcast.xml is the app's SUFeedURL.
#
# The login keychain needs:
#   - a "Developer ID Application" certificate of team $TEAM_ID
#     (Xcode › Settings › Accounts › Manage Certificates… › + › Developer ID Application)
#   - notarytool credentials saved as $NOTARY_PROFILE, once:
#       xcrun notarytool store-credentials open-caffeine-notary \
#           --apple-id <Apple ID> --team-id KN8CUHG7SN
#   - Sparkle's EdDSA private key
#
# Usage:  Scripts/release.sh
#   SIGN_IDENTITY=<SHA-1 or name>  sign with another certificate of the team
#   SIGN_ONLY=1                    stop once the app is signed and checked
#                                  (no notarization, zip, or appcast)
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"

TEAM_ID="${TEAM_ID:-KN8CUHG7SN}"
NOTARY_PROFILE="${NOTARY_PROFILE:-open-caffeine-notary}"
SIGN_ONLY="${SIGN_ONLY:-0}"

VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DIST="$REPO/dist"
DOWNLOAD_PREFIX="https://github.com/sapsaldog/open-caffeine/releases/download/v$VERSION/"

fail() { echo "✗ $*" >&2; exit 1; }

# Picked by SHA-1, so a Developer ID of another team is never used.
if [ -n "${SIGN_IDENTITY:-}" ]; then
    IDENTITY="$SIGN_IDENTITY"
else
    IDENTITY=$(security find-identity -v -p codesigning | awk -v team="($TEAM_ID)\"" \
        '!id && /"Developer ID Application: / && index($0, team) { id = $2 } END { print id }')
fi
[ -n "$IDENTITY" ] || fail "No \"Developer ID Application\" certificate of team $TEAM_ID in the keychain.
  Create one in Xcode › Settings › Accounts › Manage Certificates… › + › Developer ID Application."
if [ "$SIGN_ONLY" != 1 ]; then
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
        fail "No notarytool credentials saved as \"$NOTARY_PROFILE\". Save them once with:
  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <Apple ID> --team-id $TEAM_ID"
fi

echo "▸ Building Release v${VERSION}…"
xcodegen generate >/dev/null
# The scheme gathers test coverage, and Xcode then instruments plain builds too.
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Release \
    -derivedDataPath "$REPO/.build/release" \
    ENABLE_CODE_COVERAGE=NO CLANG_COVERAGE_MAPPING=NO build >/dev/null
APP="$REPO/.build/release/Build/Products/Release/Open Caffeine.app"
HELPER="$APP/Contents/MacOS/OpenCaffeineHelper"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
for binary in "$APP/Contents/MacOS/Open Caffeine" "$HELPER"; do
    if nm -m "$binary" | grep __llvm_profile >/dev/null; then
        fail "${binary##*/} still has code-coverage instrumentation."
    fi
done

echo "▸ Signing…"
sign() { codesign --force --timestamp --options runtime --sign "$IDENTITY" "$@"; }
# Inside out, since each signature seals the code inside it. Sparkle ships its
# helpers ad-hoc signed (Autoupdate with an application-identifier entitlement
# that has no provisioning profile behind it, so it is dropped here).
for xpc in "$SPARKLE"/Versions/Current/XPCServices/*.xpc; do
    sign --preserve-metadata=entitlements "$xpc"
done
sign "$SPARKLE/Versions/Current/Autoupdate"
sign "$SPARKLE/Versions/Current/Updater.app"
sign "$SPARKLE"
# The app pins the helper's identifier. Neither of them has entitlements.
sign --preserve-metadata=identifier "$HELPER"
sign "$APP"

echo "▸ Checking signatures…"
codesign --verify --deep --strict "$APP"
# Notarization refuses any executable not signed by the team with the hardened
# runtime and a secure timestamp.
while IFS= read -r -d '' file; do
    case "$(file -b "$file")" in Mach-O*) ;; *) continue ;; esac
    where="${file#"$APP/"}"
    info=$(codesign -dvv "$file" 2>&1) || fail "Not signed: $where"
    grep -q "^TeamIdentifier=$TEAM_ID\$" <<<"$info" || fail "Not signed by team $TEAM_ID: $where"
    grep -q '^CodeDirectory .*flags=.*runtime' <<<"$info" || fail "No hardened runtime: $where"
    grep -q '^Timestamp=' <<<"$info" || fail "No secure timestamp: $where"
done < <(find "$APP" -type f -print0)
# The app and the lid-mode helper only talk to a peer that meets this
# requirement (LidSleepHelper.requirement(forPeer:)).
peer() { echo "=identifier \"$1\" and anchor apple generic and certificate leaf[subject.OU] = \"$TEAM_ID\""; }
codesign --verify -R "$(peer com.opencaffeine.OpenCaffeine)" "$APP"
codesign --verify -R "$(peer com.opencaffeine.OpenCaffeine.helper)" "$HELPER"
AUTHORITY=$(codesign -dvv "$APP" 2>&1)
AUTHORITY=$(grep -m1 '^Authority=' <<<"$AUTHORITY")

if [ "$SIGN_ONLY" = 1 ]; then
    echo ""
    echo "✓ Signed and checked (${AUTHORITY#Authority=}): $APP"
    echo "  SIGN_ONLY: not notarized, zipped, or added to the appcast."
    exit 0
fi

GEN="$REPO/.build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
[ -x "$GEN" ] || fail "Sparkle's generate_appcast is missing at $GEN."

echo "▸ Notarizing (usually a few minutes)…"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
ditto -c -k --keepParent "$APP" "$WORK/upload.zip"
xcrun notarytool submit "$WORK/upload.zip" --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format json >"$WORK/result.json" || true
STATUS=$(plutil -extract status raw -o - "$WORK/result.json" 2>/dev/null || echo "no result")
if [ "$STATUS" != Accepted ]; then
    cat "$WORK/result.json" >&2
    if ID=$(plutil -extract id raw -o - "$WORK/result.json" 2>/dev/null); then
        xcrun notarytool log "$ID" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    fi
    fail "Notarization: $STATUS"
fi
xcrun stapler staple -q "$APP"
spctl --assess --type execute --verbose "$APP"

echo "▸ Zipping app…"
mkdir -p "$DIST"
ZIP="$DIST/Open-Caffeine-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "▸ Generating signed appcast…"
"$GEN" --download-url-prefix "$DOWNLOAD_PREFIX" "$DIST"
cp "$DIST/appcast.xml" "$REPO/appcast.xml"

echo ""
echo "✓ Built, notarized, and signed (${AUTHORITY#Authority=}): $ZIP"
echo "  Next:"
echo "  1) Commit project.yml, CHANGELOG.md, and appcast.xml as \"Release v$VERSION\"."
echo "  2) Tag that commit v$VERSION, push the tag, and upload the zip:"
echo "     gh release create v$VERSION \"$ZIP\" --verify-tag"
echo "  3) Push main — the committed appcast.xml is what SUFeedURL serves."
