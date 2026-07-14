# Shadowrocket Watchdog

This launchd job checks whether Google is reachable. If Google fails several
times while ordinary network connectivity still works, it explicitly asks
Shadowrocket to update its subscriptions, then asks Shadowrocket to reconnect.

## Install

Run:

```sh
./scripts/install.sh
bash scripts/install.sh
zsh scripts/install.sh
```

The installer reads `$SHELL` and uses it when it points to an executable Bash
or Zsh. Otherwise it falls back to `/bin/zsh`, then `/bin/bash`. The selected
absolute path is stored in the installed LaunchAgent, so every scheduled run
uses the same interpreter regardless of which shell invoked the installer.

The installer copies the runtime script into
`~/Library/Application Support/shadowrocket-watchdog/` because macOS
LaunchAgents may not be able to read scripts from `Documents`.

The job runs every 60 seconds. It triggers only after 3 consecutive Google
probe failures and then waits 15 minutes before triggering again. On trigger it
disconnects Shadowrocket, checks ordinary network connectivity outside the
broken tunnel, invokes `shadowrocket://update-subs`, waits 30 seconds, then
reconnects.

## Logs

```sh
tail -f "$HOME/Library/Application Support/shadowrocket-watchdog/watchdog.log"
```

## Tune

Edit `launchagents/local.shadowrocket-watchdog.plist`, then rerun
`./scripts/install.sh` with Bash, Zsh, or direct execution.

- `FAIL_THRESHOLD`: consecutive failures before triggering.
- `COOLDOWN_SECONDS`: minimum seconds between triggers.
- `DISCONNECT_BEFORE_TRIGGER`: disconnect Shadowrocket before opening it.
- `DISCONNECT_SETTLE_SECONDS`: wait time after disconnecting.
- `UPDATE_WAIT_SECONDS`: wait time reserved for the subscription update before
  reconnecting.
- `REOPEN_ON_TRIGGER`: set to `1` only if Shadowrocket needs a clean restart
  before handling the explicit subscription-update request.
- `RECONNECT_AFTER_TRIGGER`: set to `0` if reconnecting should be manual.

## Uninstall

```sh
./scripts/uninstall.sh
bash scripts/uninstall.sh
zsh scripts/uninstall.sh
```
