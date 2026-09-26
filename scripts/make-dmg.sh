#!/bin/bash
# Build StillOnMac.app and package it as build/StillOnMac.dmg.
# With dmgbuild installed (pip3 install dmgbuild) the DMG opens as a styled
# window: background, app icon on the left, Applications on the right.
# Without it, a plain DMG is made instead.
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/build.sh

rm -f build/StillOnMac.dmg

if command -v dmgbuild >/dev/null 2>&1; then
    dmgbuild \
        -s scripts/dmg-settings.py \
        -D app=build/StillOnMac.app \
        -D background=build/dmg-background.tiff \
        -D icon=build/StillOnMac.app/Contents/Resources/AppIcon.icns \
        "StillOnMac" \
        build/StillOnMac.dmg
else
    echo "dmgbuild not found (pip3 install dmgbuild); making a plain DMG." >&2
    STAGE="${TMPDIR:-/tmp}/stillonmac-dmg"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    ditto --norsrc --noextattr build/StillOnMac.app "$STAGE/StillOnMac.app"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create \
        -volname StillOnMac \
        -srcfolder "$STAGE" \
        -fs HFS+ \
        -format UDZO \
        -ov \
        build/StillOnMac.dmg >/dev/null
    rm -rf "$STAGE"
fi

echo "Built build/StillOnMac.dmg ($(du -h build/StillOnMac.dmg | cut -f1))"
