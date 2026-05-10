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

cp "$BIN_PATH/Ledge" "$CONTENTS/MacOS/Ledge"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy any SwiftPM-emitted resource bundle (Ledge_Ledge.bundle) into Resources/
if compgen -G "$BIN_PATH/Ledge_Ledge.bundle" > /dev/null; then
    cp -R "$BIN_PATH/Ledge_Ledge.bundle" "$CONTENTS/Resources/"
fi

# Also copy any SwiftPM SPM dependency bundles (e.g. KeyboardShortcuts_KeyboardShortcuts.bundle).
shopt -s nullglob
for bundle in "$BIN_PATH"/*.bundle; do
    name="$(basename "$bundle")"
    [[ "$name" == "Ledge_Ledge.bundle" ]] && continue
    cp -R "$bundle" "$CONTENTS/Resources/"
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
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"

    # Sign nested helpers first.
    UPDATER_APP="$SPARKLE_DEST/Versions/Current/Resources/Updater.app"
    AUTOUPDATE="$SPARKLE_DEST/Versions/Current/Resources/Autoupdate"
    INSTALLER_LAUNCHER="$SPARKLE_DEST/Versions/Current/XPCServices/Installer.xpc"
    DOWNLOADER="$SPARKLE_DEST/Versions/Current/XPCServices/Downloader.xpc"

    for nested in "$INSTALLER_LAUNCHER" "$DOWNLOADER" "$UPDATER_APP" "$AUTOUPDATE"; do
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

# Sign with Hardened Runtime + entitlements (ad-hoc identity for personal builds).
# Once you set up Developer ID, swap `-` for `Developer ID Application: NAME (TEAMID)`.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
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
