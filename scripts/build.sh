#!/bin/bash
# Builds Spoke.app into ./build.
#   SPOKE_VERSION      version string (default 0.1.0)
#   SPOKE_BUILD        build number (default 1)
#   SPOKE_SIGN_ID      code-signing identity; "-" (default) signs ad-hoc
#   SPOKE_KEYCHAIN     keychain holding SPOKE_SIGN_ID (optional)
#   SPOKE_UNIVERSAL=1  build for both Apple silicon and Intel
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${SPOKE_VERSION:-0.1.0}"
BUILD="${SPOKE_BUILD:-1}"
SIGN_ID="${SPOKE_SIGN_ID:--}"

ARCH_FLAGS=()
if [ "${SPOKE_UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}"
BIN="$(swift build -c release "${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}" --show-bin-path)/Spoke"

APP=build/Spoke.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Spoke"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

KEYCHAIN_FLAGS=()
if [ -n "${SPOKE_KEYCHAIN:-}" ]; then
    KEYCHAIN_FLAGS=(--keychain "$SPOKE_KEYCHAIN")
fi
codesign --force --sign "$SIGN_ID" "${KEYCHAIN_FLAGS[@]+"${KEYCHAIN_FLAGS[@]}"}" --identifier com.gstout.spoke "$APP"
echo "Built $APP ($VERSION, build $BUILD, signed with: $SIGN_ID)"
