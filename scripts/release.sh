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

# 2. Release build.
#
# Resolve deps so .build/checkouts/ exists, then patch the one call site in
# KeyboardShortcuts that uses Bundle.module. SwiftPM auto-generates a
# Bundle.module accessor that looks at Bundle.main.bundleURL/<name>.bundle —
# the top of the .app, outside Contents/. macOS apps put resources in
# Contents/Resources/ (codesign requires it), so the accessor never finds
# them on user machines and Bundle.module fatalErrors the first time the
# package reads its localized strings. Rather than fight the generated
# accessor (regenerated each clean build), we patch the dependency source to
# look up the bundle at the actual macOS resource location. The patch is
# idempotent: a second pass through sed leaves a patched file untouched.
echo "▶︎ Building (release)…"
swift package resolve > /dev/null
KS_UTILS=".build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"
if [[ -f "$KS_UTILS" ]]; then
    sed -i '' 's|bundle: \.module|bundle: (Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("KeyboardShortcuts_KeyboardShortcuts.bundle")) } ?? Bundle.main)|g' "$KS_UTILS"
fi

swift build -c release > /dev/null

BIN_PATH="$(swift build -c release --show-bin-path)"

# 3. Bundle
echo "▶︎ Bundling .app…"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist"     "${APP_DIR}/Contents/Info.plist"

# Bundles go in Contents/Resources/ (macOS convention, required by codesign).
# Backfill Info.plist keys so the bundle is signable (SwiftPM emits one with
# only CFBundleDevelopmentRegion).
shopt -s nullglob
for bundle in "${BIN_PATH}"/*.bundle; do
    name="$(basename "$bundle" .bundle)"
    dest="${APP_DIR}/Contents/Resources/$(basename "$bundle")"
    cp -R "$bundle" "$dest"

    plist="$dest/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.satsdisco.ledge.resources.${name}" "$plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set  :CFBundleIdentifier com.satsdisco.ledge.resources.${name}" "$plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string BNDL" "$plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set  :CFBundlePackageType BNDL" "$plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${name}" "$plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set  :CFBundleName ${name}" "$plist"
    /usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set  :CFBundleInfoDictionaryVersion 6.0" "$plist"

    codesign --force --sign "${SIGN_IDENTITY}" \
        --options runtime --timestamp \
        "$dest"
done
shopt -u nullglob

if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "${APP_DIR}/Contents/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c 'Set  :CFBundleIconFile      AppIcon' "${APP_DIR}/Contents/Info.plist"
fi

# 3a. Embed Sparkle.framework + re-sign nested helpers with our identity.
SPARKLE_SRC="${BIN_PATH}/Sparkle.framework"
if [[ -d "$SPARKLE_SRC" ]]; then
    echo "▶︎ Embedding Sparkle.framework…"
    mkdir -p "${APP_DIR}/Contents/Frameworks"
    rm -rf "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
    cp -R "$SPARKLE_SRC" "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
    SPARKLE_DEST="${APP_DIR}/Contents/Frameworks/Sparkle.framework"

    # Sign innermost helpers first, framework last. Sparkle 2.9 layout puts
    # Updater.app and Autoupdate at Versions/Current directly (not under
    # Resources/) — older guides are stale here.
    for nested in \
        "${SPARKLE_DEST}/Versions/Current/Autoupdate" \
        "${SPARKLE_DEST}/Versions/Current/Updater.app" \
        "${SPARKLE_DEST}/Versions/Current/XPCServices/Installer.xpc" \
        "${SPARKLE_DEST}/Versions/Current/XPCServices/Downloader.xpc"
    do
        if [[ -e "$nested" ]]; then
            codesign --force --sign "${SIGN_IDENTITY}" \
                --options runtime --timestamp \
                "$nested"
        fi
    done

    codesign --force --sign "${SIGN_IDENTITY}" \
        --options runtime --timestamp \
        "$SPARKLE_DEST"
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

# 8. Sparkle update signature + appcast item
SIGN_UPDATE="$(find .build/artifacts -name sign_update -type f | head -1)"
if [[ -z "$SIGN_UPDATE" ]]; then
    echo "⚠︎  sign_update not found under .build/artifacts. Run 'swift build' once" >&2
    echo "    so SwiftPM extracts the Sparkle artifact." >&2
fi

if [[ -n "$SIGN_UPDATE" ]]; then
    echo "▶︎ Signing update…"
    SIGN_OUTPUT="$("$SIGN_UPDATE" "$DMG_PATH")"
    # Output looks like: sparkle:edSignature="..." length="..."

    DMG_FILENAME="$(basename "$DMG_PATH")"
    DOWNLOAD_URL="https://github.com/satsdisco/ledge/releases/download/v${VERSION}/${DMG_FILENAME}"
    PUB_DATE="$(LC_TIME=en_US date -u '+%a, %d %b %Y %H:%M:%S +0000')"

    APPCAST_ITEM="$(cat <<XML
        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[
                <h3>Changes in ${VERSION}</h3>
                <ul>
                    <li>Replace with release notes before publishing.</li>
                </ul>
            ]]></description>
            <enclosure url="${DOWNLOAD_URL}"
                       sparkle:version="${BUILD}"
                       sparkle:shortVersionString="${VERSION}"
                       ${SIGN_OUTPUT}
                       type="application/octet-stream" />
        </item>
XML
)"

    APPCAST_OUT="${DIST}/appcast-item-${VERSION}.xml"
    printf '%s\n' "$APPCAST_ITEM" > "$APPCAST_OUT"
fi

cat <<EOF

✅ Release built
   ${DMG_PATH}
   ${SIZE_MB}    sha256: ${SHA}

Next steps (Sparkle release flow):

  1. Open ${APPCAST_OUT:-<sign_update missing>} and edit the
     <description> with real release notes.

  2. Paste that <item> block into docs/appcast.xml just inside the
     <channel> tag (newest items first).

  3. Commit and push docs/appcast.xml so GitHub Pages picks it up:

       git add docs/appcast.xml
       git commit -m "Release ${VERSION} appcast"
       git push

  4. Tag and create a GitHub release with the DMG attached:

       git tag v${VERSION} && git push --tags
       gh release create v${VERSION} "${DMG_PATH}" \\
         --title "${VERSION}" --generate-notes

  5. Existing installs will pick up the update on their next scheduled
     check (default daily) or immediately via Settings → Check Now.
EOF
