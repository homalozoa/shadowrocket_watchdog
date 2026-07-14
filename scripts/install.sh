#!/bin/sh
set -eu

select_runtime_shell() {
  candidate=${SHELL:-}
  case ${candidate##*/} in
    bash|zsh)
      if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
      ;;
  esac

  for candidate in /bin/zsh /bin/bash; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' 'No executable Bash or Zsh found.' >&2
  return 1
}

render_plist() {
  render_source_plist=$1
  render_target_plist=$2
  render_runtime_shell=$3
  render_state_dir=$4
  render_target_script=$5

  /bin/cp "$render_source_plist" "$render_target_plist"
  /usr/bin/plutil -replace ProgramArguments.0 -string "$render_runtime_shell" "$render_target_plist"
  /usr/bin/plutil -replace ProgramArguments.1 -string "$render_target_script" "$render_target_plist"
  /usr/bin/plutil -replace StandardOutPath -string "$render_state_dir/launchd.out.log" "$render_target_plist"
  /usr/bin/plutil -replace StandardErrorPath -string "$render_state_dir/launchd.err.log" "$render_target_plist"
}

install_watchdog() {
  root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
  label=local.shadowrocket-watchdog
  source_plist="$root_dir/launchagents/$label.plist"
  target_dir="$HOME/Library/LaunchAgents"
  target_plist="$target_dir/$label.plist"
  state_dir="$HOME/Library/Application Support/shadowrocket-watchdog"
  source_script="$root_dir/scripts/shadowrocket-watchdog.sh"
  target_script="$state_dir/shadowrocket-watchdog.sh"
  legacy_script="$state_dir/shadowrocket-watchdog.zsh"
  runtime_shell=$(select_runtime_shell)

  mkdir -p "$target_dir" "$state_dir"
  chmod +x "$source_script"

  /usr/bin/plutil -lint "$source_plist" >/dev/null
  /bin/cp "$source_script" "$target_script"
  /bin/chmod +x "$target_script"
  /bin/rm -f "$legacy_script"
  render_plist "$source_plist" "$target_plist" "$runtime_shell" "$state_dir" "$target_script"

  /bin/launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  /bin/launchctl bootout "gui/$(id -u)" "$target_plist" >/dev/null 2>&1 || true
  /bin/launchctl bootstrap "gui/$(id -u)" "$target_plist"
  /bin/launchctl enable "gui/$(id -u)/$label"
  /bin/launchctl kickstart -k "gui/$(id -u)/$label"

  printf 'Installed and started %s\n' "$label"
  printf 'Runtime shell: %s\n' "$runtime_shell"
  printf 'Logs: %s\n' "$state_dir/watchdog.log"
}

if [ "${WATCHDOG_INSTALL_LIB_ONLY:-0}" != 1 ]; then
  install_watchdog "$@"
fi
