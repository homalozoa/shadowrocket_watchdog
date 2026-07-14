# Bash and Zsh Auto-Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Shadowrocket watchdog install, run, and uninstall with either Bash or Zsh, selecting the launchd runtime shell from `$SHELL` during installation.

**Architecture:** Keep one portable `.sh` implementation for each command. `install.sh` exposes small shell-selection and plist-rendering functions behind an internal library-only guard so tests can exercise them without loading a real LaunchAgent; launchd receives the selected absolute interpreter path once at installation.

**Tech Stack:** POSIX-compatible shell syntax, Bash, Zsh, macOS launchd, `plutil`.

## Global Constraints

- Support only Bash and Zsh as launchd runtime interpreters.
- Prefer an executable Bash/Zsh path from `$SHELL`, then `/bin/zsh`, then `/bin/bash`.
- Preserve watchdog thresholds, cooldown, disconnect-update-reconnect flow, state files, and logs.
- Keep LaunchAgent label `local.shadowrocket-watchdog`.
- Remove obsolete installed `.zsh` runtime files during install and uninstall.
- Keep the repository free of personal paths, private IPs, subscription URLs, credentials, and tokens.

---

### Task 1: Add failing cross-shell compatibility tests

**Files:**
- Create: `tests/shell-compatibility.sh`
- Test: `tests/shell-compatibility.sh`

**Interfaces:**
- Consumes: future `select_runtime_shell`, `render_plist`, and `read_number` shell functions.
- Produces: one executable regression test covering Bash, Zsh, fallback selection, state parsing, and generated plist values.

- [ ] **Step 1: Write the failing test**

Create `tests/shell-compatibility.sh` with this structure:

```sh
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/shell-compatibility.sh`

Expected: non-zero exit because `scripts/install.sh`, `scripts/uninstall.sh`, and `scripts/shadowrocket-watchdog.sh` do not exist yet.

- [ ] **Step 3: Commit the failing test**

```sh
git add tests/shell-compatibility.sh
git commit -m "Add cross-shell compatibility tests"
```

---

### Task 2: Convert runtime and lifecycle scripts to portable shell

**Files:**
- Delete: `scripts/install.zsh`
- Delete: `scripts/uninstall.zsh`
- Delete: `scripts/shadowrocket-watchdog.zsh`
- Create: `scripts/install.sh`
- Create: `scripts/uninstall.sh`
- Create: `scripts/shadowrocket-watchdog.sh`
- Modify: `launchagents/local.shadowrocket-watchdog.plist`
- Test: `tests/shell-compatibility.sh`

**Interfaces:**
- Produces: `select_runtime_shell() -> absolute Bash/Zsh path`, `render_plist(source, target, runtime_shell, state_dir, target_script)`, and `read_number(file, fallback) -> decimal string`.
- Consumes: `WATCHDOG_INSTALL_LIB_ONLY=1` and `WATCHDOG_LIB_ONLY=1` only in tests to suppress top-level side effects.

- [ ] **Step 1: Implement shell detection and plist rendering**

Create `scripts/install.sh` using `/bin/sh` syntax. The key functions must be:

```sh
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
  source_plist=$1
  target_plist=$2
  runtime_shell=$3
  state_dir=$4
  target_script=$5

  /bin/cp "$source_plist" "$target_plist"
  /usr/bin/plutil -replace ProgramArguments.0 -string "$runtime_shell" "$target_plist"
  /usr/bin/plutil -replace ProgramArguments.1 -string "$target_script" "$target_plist"
  /usr/bin/plutil -replace StandardOutPath -string "$state_dir/launchd.out.log" "$target_plist"
  /usr/bin/plutil -replace StandardErrorPath -string "$state_dir/launchd.err.log" "$target_plist"
}
```

The main installer selects the runtime before copying files, installs
`shadowrocket-watchdog.sh`, removes `shadowrocket-watchdog.zsh` only after the
new file is present, renders the plist, reloads launchd, and prints the chosen
path, for example `Runtime shell: /bin/zsh`. Wrap main execution with:

```sh
if [ "${WATCHDOG_INSTALL_LIB_ONLY:-0}" != 1 ]; then
  install_watchdog "$@"
fi
```

- [ ] **Step 2: Port watchdog state parsing and output**

Create `scripts/shadowrocket-watchdog.sh` with the existing behavior. Replace
Zsh numeric matching and `print` with:

```sh
read_number() {
  file=$1
  fallback=$2
  value=$(cat "$file" 2>/dev/null || true)
  case $value in
    ''|*[!0-9]*) printf '%s\n' "$fallback" ;;
    *) printf '%s\n' "$value" ;;
  esac
}
```

Use `[ ... ]`, `printf`, and POSIX arithmetic throughout. Put all runtime work
in `run_watchdog()` and guard it with:

```sh
if [ "${WATCHDOG_LIB_ONLY:-0}" != 1 ]; then
  run_watchdog "$@"
fi
```

- [ ] **Step 3: Port uninstall and update plist defaults**

Create `scripts/uninstall.sh` with `/bin/sh`, keep the existing LaunchAgent
shutdown/removal behavior, and remove both:

```sh
"$HOME/Library/Application Support/shadowrocket-watchdog/shadowrocket-watchdog.sh"
"$HOME/Library/Application Support/shadowrocket-watchdog/shadowrocket-watchdog.zsh"
```

Update the source plist defaults to `/bin/zsh` and the generic
`/Users/USERNAME/.../shadowrocket-watchdog.sh` path. The installer replaces
both values before bootstrap.

- [ ] **Step 4: Run tests to verify the implementation passes**

Run:

```sh
sh tests/shell-compatibility.sh
bash tests/shell-compatibility.sh
zsh tests/shell-compatibility.sh
```

Expected: each command prints `shell compatibility tests passed` and exits 0.

- [ ] **Step 5: Verify no Zsh-only syntax or stale public filenames remain**

Run:

```sh
if rg -n '<->|print -r|\[\[' scripts README.md launchagents; then exit 1; fi
if rg -n 'install\.zsh|uninstall\.zsh|shadowrocket-watchdog\.zsh' README.md launchagents; then exit 1; fi
```

Expected: both searches produce no output and exit through the inverted checks successfully. The compatibility cleanup reference inside `uninstall.sh` is intentionally excluded from the second scan.

- [ ] **Step 6: Commit portable scripts**

```sh
git add scripts launchagents/local.shadowrocket-watchdog.plist tests/shell-compatibility.sh
git commit -m "Support Bash and Zsh runtimes"
```

---

### Task 3: Document selection behavior and run release verification

**Files:**
- Modify: `README.md`
- Test: `tests/shell-compatibility.sh`

**Interfaces:**
- Consumes: `scripts/install.sh`, `scripts/uninstall.sh`, and `$SHELL` selection behavior from Task 2.
- Produces: user-facing install, shell-selection, tuning, and uninstall instructions.

- [ ] **Step 1: Update README commands and behavior**

Replace `.zsh` commands with:

```sh
./scripts/install.sh
bash scripts/install.sh
zsh scripts/install.sh
```

Explain that installation reads `$SHELL`, accepts executable Bash/Zsh paths,
falls back to `/bin/zsh` and then `/bin/bash`, and writes the selected path to
the installed LaunchAgent. Update uninstall to `./scripts/uninstall.sh`.

- [ ] **Step 2: Run the complete validation suite**

Run:

```sh
sh tests/shell-compatibility.sh
bash tests/shell-compatibility.sh
zsh tests/shell-compatibility.sh
plutil -lint launchagents/local.shadowrocket-watchdog.plist
git diff --check
```

Expected: three compatibility success messages, plist `OK`, and no diff errors.

- [ ] **Step 3: Run privacy and scope scans**

Run:

```sh
sensitive_pattern='github_''pat_|gh''p_|BE''GIN [A-Z ]*PRIVATE KEY|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+'
if rg -n -S "$sensitive_pattern" . -g '!/.git/**'; then exit 1; fi
user_path_pattern='/''Users/'
generic_user_path='/''Users/USERNAME'
if rg -n "$user_path_pattern" . -g '!/.git/**' | rg -v "$generic_user_path"; then exit 1; fi
git status -sb
git diff --stat
```

Expected: privacy scan has no matches; status and stat list only the planned shell-support changes.

- [ ] **Step 4: Commit documentation**

```sh
git add README.md docs/superpowers/plans/2026-07-14-bash-zsh-auto-detection.md
git commit -m "Document automatic shell selection"
```

- [ ] **Step 5: Verify final repository state**

Run:

```sh
git status -sb
git log -4 --oneline --decorate
```

Expected: clean working tree on `main`, ahead of `origin/main` by the new local commits until explicitly pushed.
