#!/bin/bash
# Build StillOnMac.app and package it as build/StillOnMac.dmg
# (drag-to-Applications window).
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build.sh

STAGE="${TMPDIR:-/tmp}/stillonmac-dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto --norsrc --noextattr build/StillOnMac.app "$STAGE/StillOnMac.app"
ln -s /Applications "$STAGE/Applications"

rm -f build/StillOnMac.dmg
hdiutil create \
    -volname StillOnMac \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    build/StillOnMac.dmg >/dev/null
rm -rf "$STAGE"

echo "Built build/StillOnMac.dmg"
