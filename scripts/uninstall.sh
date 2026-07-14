#!/bin/sh
set -eu

LABEL=local.shadowrocket-watchdog
TARGET_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
STATE_DIR="$HOME/Library/Application Support/shadowrocket-watchdog"
TARGET_SCRIPT="$STATE_DIR/shadowrocket-watchdog.sh"
LEGACY_SCRIPT="$STATE_DIR/shadowrocket-watchdog.zsh"

/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
/bin/rm -f "$TARGET_PLIST"
/bin/rm -f "$TARGET_SCRIPT" "$LEGACY_SCRIPT"

printf 'Uninstalled %s\n' "$LABEL"
printf 'State/logs kept at: %s\n' "$STATE_DIR"
