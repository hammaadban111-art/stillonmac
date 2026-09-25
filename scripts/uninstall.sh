#!/bin/bash
# Undo StillOnMac's system changes. Run: sudo ./scripts/uninstall.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

pkill -x StillOnMac 2>/dev/null || true

pmset -a disablesleep 0
echo "✓ Normal sleep restored"

rm -f /etc/sudoers.d/stillonmac
echo "✓ Lid-closed helper removed"

defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true
echo "✓ Automatic macOS update installs back on"

if [[ -d /Applications/StillOnMac.app ]]; then
    rm -rf /Applications/StillOnMac.app
    echo "✓ Removed /Applications/StillOnMac.app"
fi

echo "Done. If it still shows under System Settings → General → Login Items, remove it there."
