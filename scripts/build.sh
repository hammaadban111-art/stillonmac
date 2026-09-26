#!/bin/bash
# Build StillOnMac.app with the Xcode command line tools.
#   ./scripts/build.sh            → build/StillOnMac.app
#   ./scripts/build.sh --install  → also copy to /Applications and open it
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found. Install the tools first: xcode-select --install" >&2
    exit 1
fi

# Build outside the project folder: iCloud-synced folders like Desktop add
# extended attributes that make codesign fail.
STAGE="${TMPDIR:-/tmp}/stillonmac-build"
APP="$STAGE/StillOnMac.app"
ARCH="$(uname -m)"

rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=()
while IFS= read -r -d '' file; do
    SOURCES+=("$file")
done < <(find Sources -name '*.swift' -print0)

echo "Compiling for ${ARCH}..."
swiftc -O \
    -target "$ARCH-apple-macos13.0" \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    -framework ApplicationServices \
    "${SOURCES[@]}" \
    -o "$APP/Contents/MacOS/StillOnMac"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp scripts/setup-power.sh "$APP/Contents/Resources/setup-power.sh"
chmod +x "$APP/Contents/Resources/setup-power.sh"

# App icon and DMG background, drawn by scripts/make-art.swift.
ART="$STAGE/art"
if swift scripts/make-art.swift "$ART" >/dev/null \
    && iconutil -c icns "$ART/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"; then
    tiffutil -cathidpicheck "$ART/dmg-background.png" "$ART/dmg-background@2x.png" \
        -out "$ART/dmg-background.tiff" >/dev/null 2>&1 || cp "$ART/dmg-background.png" "$ART/dmg-background.tiff"
    echo "App icon added"
else
    echo "warning: couldn't draw the app icon; building without it" >&2
fi

xattr -cr "$APP"
codesign --force --sign - "$APP"

rm -rf build
mkdir -p build
ditto --norsrc --noextattr "$APP" build/StillOnMac.app
if [[ -f "$ART/dmg-background.tiff" ]]; then
    cp "$ART/dmg-background.tiff" build/dmg-background.tiff
fi
echo "Built build/StillOnMac.app"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x StillOnMac 2>/dev/null || true
    sleep 1
    rm -rf /Applications/StillOnMac.app
    ditto --norsrc --noextattr "$APP" /Applications/StillOnMac.app
    # A rebuilt app has a new signature, so the old Accessibility grant no longer matches.
    tccutil reset Accessibility com.stillonmac.app >/dev/null 2>&1 || true
    open /Applications/StillOnMac.app
    echo "Installed to /Applications and launched. Re-grant Accessibility if asked."
fi
