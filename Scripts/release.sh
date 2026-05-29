#!/usr/bin/env bash
#
# Build, EdDSA-sign, and (re)generate the Sparkle appcast for a release.
# Then upload the produced zip to a GitHub release and commit appcast.xml —
# raw.githubusercontent.com/.../appcast.xml is the app's SUFeedURL.
#
# Usage:  Scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"

VERSION=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
DIST="$REPO/dist"
DOWNLOAD_PREFIX="https://github.com/sapsaldog/open-caffeine/releases/download/v$VERSION/"

GEN=$(find "$HOME/Library/Developer/Xcode/DerivedData"/OpenCaffeine-*/SourcePackages/artifacts/sparkle/Sparkle/bin \
        -name generate_appcast 2>/dev/null | head -1)
if [ -z "$GEN" ]; then
    echo "Sparkle's generate_appcast not found — build once in Xcode to resolve packages first."
    exit 1
fi

echo "▸ Building Release v$VERSION…"
xcodegen generate >/dev/null
xcodebuild -project OpenCaffeine.xcodeproj -scheme OpenCaffeine -configuration Release \
    -derivedDataPath "$REPO/.build/release" build >/dev/null
APP="$REPO/.build/release/Build/Products/Release/Open Caffeine.app"

echo "▸ Zipping app…"
mkdir -p "$DIST"
ZIP="$DIST/Open-Caffeine-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "▸ Generating signed appcast…"
"$GEN" --download-url-prefix "$DOWNLOAD_PREFIX" "$DIST"
cp "$DIST/appcast.xml" "$REPO/appcast.xml"

echo ""
echo "✓ Built + signed: $ZIP"
echo "  Next:"
echo "  1) Create GitHub release tag v$VERSION and upload $ZIP as an asset."
echo "  2) git add appcast.xml && git commit -m \"Release v$VERSION\" && git push"
echo "     (the committed appcast.xml is what SUFeedURL serves)."
