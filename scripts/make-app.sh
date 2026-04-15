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

codesign --force --sign - --timestamp=none "$APP_DIR"

echo
echo "✅ Built $APP_DIR"
echo "Run with: open $APP_DIR"
