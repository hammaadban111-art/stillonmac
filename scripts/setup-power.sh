#!/bin/bash
# One-time setup for StillOnMac. Run as root:
#   sudo ./scripts/setup-power.sh            (from Terminal)
# The app's "Run Setup…" button runs this same script with your username.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo $0" >&2
    exit 1
fi

TARGET_USER="${1:-${SUDO_USER:-}}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    echo "Could not tell which user to set up. Run: sudo $0 <your-username>" >&2
    exit 1
fi
if [[ ! "$TARGET_USER" =~ ^[A-Za-z0-9._-]+$ ]] || ! id "$TARGET_USER" >/dev/null 2>&1; then
    echo "Unknown user: $TARGET_USER" >&2
    exit 1
fi

# 1. Let the app toggle lid-closed sleep without a password.
#    Only these two exact commands are allowed, nothing else.
SUDOERS=/etc/sudoers.d/stillonmac
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<EOF
# StillOnMac: allow toggling lid-closed sleep without a password
$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
EOF
visudo -cf "$TMP" >/dev/null
mkdir -p /etc/sudoers.d
install -m 0440 -o root -g wheel "$TMP" "$SUDOERS"
echo "✓ Lid-closed helper installed ($SUDOERS)"

# 2. Keep the network alive for remote sessions.
pmset -a tcpkeepalive 1 >/dev/null 2>&1 || true
pmset -a womp 1 >/dev/null 2>&1 || true
pmset -c powernap 0 >/dev/null 2>&1 || true
echo "✓ Network keep-alive on"

# 3. Stop macOS from installing updates and restarting on its own.
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
echo "✓ Automatic macOS update installs off (you can still update by hand)"

# 4. No screen saver taking over the external display.
sudo -u "$TARGET_USER" defaults -currentHost write com.apple.screensaver idleTime -int 0
echo "✓ Screen saver off"

echo "Done."
