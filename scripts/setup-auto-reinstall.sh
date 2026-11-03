#!/bin/bash
# Installs or updates the launchd agent that keeps Spendly installed on the iPhone.
# Usage: setup-auto-reinstall.sh <device-id> [hour]   (default hour: 23)
# Remove: launchctl bootout gui/$(id -u)/com.sameetasadullah.spendly.reinstall
#         rm ~/Library/LaunchAgents/com.sameetasadullah.spendly.reinstall.plist
set -euo pipefail

DEVICE="${1:?usage: setup-auto-reinstall.sh <device-id> [hour]}"
HOUR="${2:-23}"
LABEL="com.sameetasadullah.spendly.reinstall"
BASE="$HOME/Library/Application Support/Spendly"
SCRIPT="$BASE/install-on-iphone.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
install -m 755 "$(dirname "$0")/install-on-iphone.sh" "$SCRIPT"
rm -f "$BASE/last-install"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SCRIPT</string>
        <string>$DEVICE</string>
        <string>2</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$HOUR</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$BASE/reinstall.log</string>
    <key>StandardErrorPath</key>
    <string>$BASE/reinstall.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Agent $LABEL runs daily at $HOUR:00 and reinstalls when the installed build has 2 days or less left."
