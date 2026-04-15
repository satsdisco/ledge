#!/usr/bin/env bash
# Ledge release pipeline.
#
# 1. Builds release binary
# 2. Bundles into Ledge.app with Hardened Runtime + entitlements
# 3. Signs with Developer ID
# 4. Wraps in a DMG
# 5. Optionally notarizes + staples (pass --notarize)
#
# Prerequisites for notarization (one-time setup):
#
#   1. Generate an app-specific password at appleid.apple.com →
#      Sign-In and Security → App-Specific Passwords.
#   2. Store credentials in keychain so notarytool can use them:
#
#      xcrun notarytool store-credentials "ledge-notary" \
#          --apple-id "your@apple.id" \
#          --team-id  "55XV5874TM" \
#          --password "abcd-efgh-ijkl-mnop"
#
#   3. Run this script with `--notarize`. The DMG will be submitted,
#      polled, and stapled.
#
# Usage:
#   scripts/release.sh                    # build + sign + DMG (no notarize)
#   scripts/release.sh --notarize         # full pipeline
#   SIGN_IDENTITY="..." scripts/release.sh   # override signing identity
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NOTARIZE=0
for arg in "$@"; do
    case "$arg" in
        --notarize) NOTARIZE=1 ;;
    esac
done

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: John Grafton Clark (55XV5874TM)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ledge-notary}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
DIST="dist"
APP_NAME="Ledge"
APP_DIR="${DIST}/${APP_NAME}.app"
DMG_PATH="${DIST}/${APP_NAME}-${VERSION}.dmg"
STAGING="${DIST}/dmg-staging"

echo "▶︎ Ledge ${VERSION} (build ${BUILD})"
echo "▶︎ Identity: ${SIGN_IDENTITY}"
echo "▶︎ Notarize: $([[ $NOTARIZE -eq 1 ]] && echo yes || echo no)"
echo

# 1. Clean
rm -rf "$DIST"
mkdir -p "$DIST"

# 2. Release build
echo "▶︎ Building (release)…"
swift build -c release > /dev/null

BIN_PATH="$(swift build -c release --show-bin-path)"

# 3. Bundle
echo "▶︎ Bundling .app…"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist"     "${APP_DIR}/Contents/Info.plist"

shopt -s nullglob
for bundle in "${BIN_PATH}"/*.bundle; do
    cp -R "$bundle" "${APP_DIR}/Contents/Resources/"
done
shopt -u nullglob

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "${APP_DIR}/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c 'Set  :CFBundleIconFile      AppIcon' "${APP_DIR}/Contents/Info.plist"
fi

# 4. Sign
echo "▶︎ Signing…"
codesign --force \
    --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --entitlements "Resources/Ledge.entitlements" \
    --timestamp \
    "${APP_DIR}"

codesign --verify --deep --strict --verbose=2 "${APP_DIR}" 2>&1 | tail -3

# 5. DMG
echo "▶︎ Building DMG…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname "${APP_NAME} ${VERSION}" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" > /dev/null

rm -rf "$STAGING"

echo "▶︎ Signing DMG…"
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "$DMG_PATH"

# 6. Notarize
if [[ $NOTARIZE -eq 1 ]]; then
    echo "▶︎ Submitting to Apple notary…"
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "▶︎ Stapling…"
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

# 7. Checksums
SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
SIZE_MB="$(du -h "$DMG_PATH" | awk '{print $1}')"

cat <<EOF

✅ Release built
   ${DMG_PATH}
   ${SIZE_MB}    sha256: ${SHA}

Distribute by uploading the DMG to your release host and publishing
the SHA-256 alongside the download link.
EOF
