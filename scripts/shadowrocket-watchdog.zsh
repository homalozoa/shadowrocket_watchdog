#!/bin/zsh
set -euo pipefail

APP_BUNDLE_ID="com.liguangming.Shadowrocket"
STATE_DIR="$HOME/Library/Application Support/shadowrocket-watchdog"
LOG_FILE="$STATE_DIR/watchdog.log"
FAIL_FILE="$STATE_DIR/fail_count"
LAST_TRIGGER_FILE="$STATE_DIR/last_trigger"

# Tunables. Override from launchd plist EnvironmentVariables when needed.
GOOGLE_PROBE_URL="${GOOGLE_PROBE_URL:-https://www.google.com/generate_204}"
BASIC_NET_PROBE_URL="${BASIC_NET_PROBE_URL:-https://www.apple.com/library/test/success.html}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-5}"
MAX_TIME="${MAX_TIME:-8}"
FAIL_THRESHOLD="${FAIL_THRESHOLD:-3}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-900}"
DISCONNECT_BEFORE_TRIGGER="${DISCONNECT_BEFORE_TRIGGER:-1}"
DISCONNECT_SETTLE_SECONDS="${DISCONNECT_SETTLE_SECONDS:-5}"
UPDATE_WAIT_SECONDS="${UPDATE_WAIT_SECONDS:-30}"
REOPEN_ON_TRIGGER="${REOPEN_ON_TRIGGER:-0}"
RECONNECT_AFTER_TRIGGER="${RECONNECT_AFTER_TRIGGER:-1}"

mkdir -p "$STATE_DIR"

log() {
  local message="$1"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$message" >> "$LOG_FILE"
}

probe_url() {
  local url="$1"
  /usr/bin/curl -fsSI \
    --connect-timeout "$CONNECT_TIMEOUT" \
    --max-time "$MAX_TIME" \
    "$url" >/dev/null
}

read_number() {
  local file="$1"
  local fallback="$2"
  local value
  value="$(cat "$file" 2>/dev/null || true)"
  if [[ "$value" == <-> ]]; then
    print -r -- "$value"
  else
    print -r -- "$fallback"
  fi
}

now="$(date +%s)"
fails="$(read_number "$FAIL_FILE" 0)"
last_trigger="$(read_number "$LAST_TRIGGER_FILE" 0)"

if probe_url "$GOOGLE_PROBE_URL"; then
  if [[ "$fails" -ne 0 ]]; then
    log "google_probe_ok reset_fail_count previous=$fails"
  fi
  print -r -- 0 > "$FAIL_FILE"
  exit 0
fi

fails=$((fails + 1))
print -r -- "$fails" > "$FAIL_FILE"
log "google_probe_failed count=$fails url=$GOOGLE_PROBE_URL"

if (( fails < FAIL_THRESHOLD )); then
  exit 0
fi

if (( now - last_trigger < COOLDOWN_SECONDS )); then
  log "cooldown_active skip_trigger remaining=$((COOLDOWN_SECONDS - (now - last_trigger)))"
  exit 0
fi

log "prepare_shadowrocket_trigger disconnect=$DISCONNECT_BEFORE_TRIGGER"

if [[ "$DISCONNECT_BEFORE_TRIGGER" == "1" ]]; then
  /usr/bin/open 'shadowrocket://disconnect' >/dev/null 2>&1 || true
  sleep "$DISCONNECT_SETTLE_SECONDS"
fi

if ! probe_url "$BASIC_NET_PROBE_URL"; then
  log "basic_net_probe_failed_after_disconnect skip_trigger url=$BASIC_NET_PROBE_URL"
  if [[ "$DISCONNECT_BEFORE_TRIGGER" == "1" && "$RECONNECT_AFTER_TRIGGER" == "1" ]]; then
    /usr/bin/open 'shadowrocket://connect' >/dev/null 2>&1 || true
  fi
  exit 0
fi

print -r -- "$now" > "$LAST_TRIGGER_FILE"
log "trigger_shadowrocket_update reopen=$REOPEN_ON_TRIGGER update_wait=$UPDATE_WAIT_SECONDS reconnect=$RECONNECT_AFTER_TRIGGER"

if [[ "$REOPEN_ON_TRIGGER" == "1" ]]; then
  /usr/bin/osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  sleep 3
fi

/usr/bin/open 'shadowrocket://update-subs'
sleep "$UPDATE_WAIT_SECONDS"

if [[ "$RECONNECT_AFTER_TRIGGER" == "1" ]]; then
  /usr/bin/open 'shadowrocket://connect' >/dev/null 2>&1 || true
fi
