#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="local.shadowrocket-watchdog"
SOURCE_PLIST="$ROOT_DIR/launchagents/$LABEL.plist"
TARGET_DIR="$HOME/Library/LaunchAgents"
TARGET_PLIST="$TARGET_DIR/$LABEL.plist"
STATE_DIR="$HOME/Library/Application Support/shadowrocket-watchdog"
TARGET_SCRIPT="$STATE_DIR/shadowrocket-watchdog.zsh"

mkdir -p "$TARGET_DIR" "$STATE_DIR"
chmod +x "$ROOT_DIR/scripts/shadowrocket-watchdog.zsh"

/usr/bin/plutil -lint "$SOURCE_PLIST" >/dev/null
/bin/cp "$ROOT_DIR/scripts/shadowrocket-watchdog.zsh" "$TARGET_SCRIPT"
/bin/chmod +x "$TARGET_SCRIPT"
/bin/cp "$SOURCE_PLIST" "$TARGET_PLIST"
/usr/bin/plutil -replace ProgramArguments.1 -string "$TARGET_SCRIPT" "$TARGET_PLIST"
/usr/bin/plutil -replace StandardOutPath -string "$STATE_DIR/launchd.out.log" "$TARGET_PLIST"
/usr/bin/plutil -replace StandardErrorPath -string "$STATE_DIR/launchd.err.log" "$TARGET_PLIST"

/bin/launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
/bin/launchctl bootout "gui/$(id -u)" "$TARGET_PLIST" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$(id -u)" "$TARGET_PLIST"
/bin/launchctl enable "gui/$(id -u)/$LABEL"
/bin/launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and started $LABEL"
echo "Logs: $STATE_DIR/watchdog.log"
