# Bash and Zsh Auto-Detection Design

## Goal

Support installing, running, and uninstalling the Shadowrocket watchdog with
either Bash or Zsh. Detect the user's login shell at installation time and
store that choice in the generated LaunchAgent configuration.

## Scope

- Replace the Zsh-specific public scripts with portable `.sh` scripts.
- Support explicit invocation with both `bash` and `zsh`.
- Detect Bash or Zsh from `$SHELL` during installation.
- Preserve the existing watchdog behavior, timing, state, and logging.
- Migrate an existing `.zsh` runtime script without leaving duplicate files.

No other shells or non-macOS service managers are in scope.

## Architecture

The repository will contain one implementation of each script:

- `scripts/install.sh`
- `scripts/shadowrocket-watchdog.sh`
- `scripts/uninstall.sh`

All three scripts will use syntax accepted by both Bash and Zsh. The installer
will choose the runtime interpreter once and write its absolute path into
`ProgramArguments[0]` in the installed plist. The watchdog will therefore use
a stable interpreter on every launchd run instead of repeating detection.
The scripts will use a `/bin/sh` shebang for direct execution while remaining
explicitly validated under Bash and Zsh.

## Shell Selection

The installer will:

1. Read `$SHELL`.
2. Accept it only when its basename is `bash` or `zsh` and the path is
   executable.
3. Otherwise fall back to `/bin/zsh` when executable.
4. Otherwise fall back to `/bin/bash` when executable.
5. Exit with a clear error when neither interpreter is available.

The installer will print the selected interpreter so the deployed behavior is
observable.

## Compatibility Changes

Zsh-only constructs such as `[[ ... ]]`, the `<->` numeric glob, and
`print -r` will be replaced with portable `case`, `[ ... ]`, and `printf`
constructs. Existing environment-variable tuning remains unchanged.

The installed runtime filename becomes `shadowrocket-watchdog.sh`. A successful
installation removes the obsolete `shadowrocket-watchdog.zsh`. Uninstallation
removes both filenames so upgrades and rollback attempts do not leave stale
runtime copies.

The LaunchAgent label remains `local.shadowrocket-watchdog`; only its
interpreter and script path are generated at install time.

## Documentation

The README will document all supported forms:

```sh
./scripts/install.sh
bash scripts/install.sh
zsh scripts/install.sh
```

It will explain that `$SHELL` controls the interpreter selected for launchd,
independent of which shell happens to invoke the installer.

## Verification

- `bash -n` passes for every `.sh` script.
- `zsh -n` passes for every `.sh` script.
- Watchdog numeric-state parsing is exercised under both Bash and Zsh.
- Shell selection is checked for Bash, Zsh, and invalid `$SHELL` fallback
  without loading a real LaunchAgent.
- The generated plist passes `plutil -lint` and contains the selected shell and
  `.sh` runtime path.
- The repository privacy scan remains clean.

## Error Handling

Installation fails before modifying launchd if no supported executable shell
can be selected. An invalid `$SHELL` value is never written into the plist.
Existing launchctl errors continue to stop installation through `set -eu`.
