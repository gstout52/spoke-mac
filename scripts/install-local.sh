#!/bin/bash
# Builds Spoke signed with a stable local identity and installs it to /Applications.
# A stable signature means macOS keeps the Microphone and Accessibility permissions
# across rebuilds. Create the identity once (see README, "Building it yourself").
set -euo pipefail
cd "$(dirname "$0")/.."

KEYCHAIN="${SPOKE_KEYCHAIN:-$HOME/.spoke-mac/signing.keychain-db}"
PASSWORD_FILE="${SPOKE_KEYCHAIN_PASSWORD_FILE:-$HOME/.spoke-mac/keychain_password.txt}"
security unlock-keychain -p "$(cat "$PASSWORD_FILE")" "$KEYCHAIN"
ID=$(security find-identity -p codesigning "$KEYCHAIN" | awk '/Spoke Local Signing/ {print $2; exit}')

BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo 1)
SPOKE_SIGN_ID="$ID" SPOKE_KEYCHAIN="$KEYCHAIN" SPOKE_BUILD="$BUILD_NUMBER" ./scripts/build.sh

pkill -x Spoke 2>/dev/null || true
rm -rf /Applications/Spoke.app
cp -R build/Spoke.app /Applications/
open /Applications/Spoke.app
echo "Installed /Applications/Spoke.app"
