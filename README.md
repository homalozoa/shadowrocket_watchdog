# Shadowrocket Watchdog

This launchd job checks whether Google is reachable. If Google fails several
times while ordinary network connectivity still works, it explicitly asks
Shadowrocket to update its subscriptions, then asks Shadowrocket to reconnect.

## Install

Run:

```sh
./scripts/install.zsh
```

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
`./scripts/install.zsh`.

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
./scripts/uninstall.zsh
```
