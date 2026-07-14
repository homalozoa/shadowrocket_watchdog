#!/bin/zsh
set -euo pipefail

LABEL="local.shadowrocket-watchdog"
TARGET_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
TARGET_SCRIPT="$HOME/Library/Application Support/shadowrocket-watchdog/shadowrocket-watchdog.zsh"

/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
/bin/rm -f "$TARGET_PLIST"
/bin/rm -f "$TARGET_SCRIPT"

echo "Uninstalled $LABEL"
echo "State/logs kept at: $HOME/Library/Application Support/shadowrocket-watchdog"
