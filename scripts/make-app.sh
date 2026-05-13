#!/usr/bin/env bash
# Wraps the SwiftPM-built Ledge executable into a macOS .app bundle,
# copies Info.plist, and ad-hoc codesigns. Output: build/Ledge.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIG:-debug}"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="build/Ledge.app"
CONTENTS="$APP_DIR/Contents"

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# Ad-hoc identity for personal builds. Swap for `Developer ID Application: …`
# when producing distributable builds (release.sh handles that path).
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cp "$BIN_PATH/Ledge" "$CONTENTS/MacOS/Ledge"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy SwiftPM-emitted resource bundles (Ledge_Ledge.bundle plus any SPM
# dependency bundles like KeyboardShortcuts_KeyboardShortcuts.bundle).
# SwiftPM emits each with a near-empty Info.plist (CFBundleDevelopmentRegion
# only); macOS 26 rejects Bundle(url:) for that, so Bundle.module fatalErrors
# the first time the package reads its resources. Backfill required keys and
# codesign each bundle before sealing the app.
shopt -s nullglob
for bundle in "$BIN_PATH"/*.bundle; do
    name="$(basename "$bundle" .bundle)"
    dest="$CONTENTS/Resources/$(basename "$bundle")"
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

    codesign --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp=none \
        "$dest"
done
shopt -u nullglob

# Embed Sparkle.framework for auto-updates. SwiftPM extracts it into the build
# artifacts dir; we copy it into Contents/Frameworks and sign each piece in
# the order Sparkle requires (XPC services & helpers signed before the
# umbrella framework, framework before the host app).
SPARKLE_SRC="$BIN_PATH/Sparkle.framework"
if [[ -d "$SPARKLE_SRC" ]]; then
    mkdir -p "$CONTENTS/Frameworks"
    rm -rf "$CONTENTS/Frameworks/Sparkle.framework"
    cp -R "$SPARKLE_SRC" "$CONTENTS/Frameworks/Sparkle.framework"
    SPARKLE_DEST="$CONTENTS/Frameworks/Sparkle.framework"

    # Sign nested helpers first. Sparkle 2.9 layout puts Updater.app and
    # Autoupdate at Versions/Current directly, not under Resources/.
    for nested in \
        "$SPARKLE_DEST/Versions/Current/Autoupdate" \
        "$SPARKLE_DEST/Versions/Current/Updater.app" \
        "$SPARKLE_DEST/Versions/Current/XPCServices/Installer.xpc" \
        "$SPARKLE_DEST/Versions/Current/XPCServices/Downloader.xpc"
    do
        if [[ -e "$nested" ]]; then
            codesign --force --sign "$SIGN_IDENTITY" \
                --options runtime \
                --timestamp=none \
                "$nested" 2>/dev/null || true
        fi
    done

    # Sign the framework itself last.
    codesign --force --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp=none \
        "$SPARKLE_DEST"
fi

codesign --force \
    --sign "$SIGN_IDENTITY" \
    --options runtime \
    --entitlements "Resources/Ledge.entitlements" \
    --timestamp=none \
    "$APP_DIR"

echo "Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP_DIR" 2>&1 | tail -3 || true

echo
echo "✅ Built $APP_DIR"
echo "Run with: open $APP_DIR"
