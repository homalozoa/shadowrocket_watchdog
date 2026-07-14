#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

for runtime in /bin/bash /bin/zsh; do
  "$runtime" -n "$ROOT_DIR/scripts/install.sh"
  "$runtime" -n "$ROOT_DIR/scripts/uninstall.sh"
  "$runtime" -n "$ROOT_DIR/scripts/shadowrocket-watchdog.sh"

  selected=$(
    SHELL="$runtime" WATCHDOG_INSTALL_LIB_ONLY=1 "$runtime" -c \
      '. "$1/scripts/install.sh"; select_runtime_shell' shell-test "$ROOT_DIR"
  )
  [ "$selected" = "$runtime" ]

  printf '42\n' > "$TMP_DIR/number"
  value=$(
    WATCHDOG_LIB_ONLY=1 "$runtime" -c \
      '. "$1/scripts/shadowrocket-watchdog.sh"; read_number "$2" 0' \
      shell-test "$ROOT_DIR" "$TMP_DIR/number"
  )
  [ "$value" = 42 ]
done

fallback=$(
  SHELL=/bin/fish WATCHDOG_INSTALL_LIB_ONLY=1 /bin/sh -c \
    '. "$1/scripts/install.sh"; select_runtime_shell' shell-test "$ROOT_DIR"
)
[ "$fallback" = /bin/zsh ]

WATCHDOG_INSTALL_LIB_ONLY=1 /bin/sh -c '
  . "$1/scripts/install.sh"
  render_plist "$1/launchagents/local.shadowrocket-watchdog.plist" \
    "$2/generated.plist" /bin/bash "$2/state" "$2/watchdog.sh"
' shell-test "$ROOT_DIR" "$TMP_DIR"

plutil -lint "$TMP_DIR/generated.plist" >/dev/null
[ "$(plutil -extract ProgramArguments.0 raw "$TMP_DIR/generated.plist")" = /bin/bash ]
[ "$(plutil -extract ProgramArguments.1 raw "$TMP_DIR/generated.plist")" = "$TMP_DIR/watchdog.sh" ]
printf 'shell compatibility tests passed\n'
