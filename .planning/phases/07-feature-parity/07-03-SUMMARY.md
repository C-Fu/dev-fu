---
phase: 07-feature-parity
plan: 03
subsystem: modules
tags: [modules, posix-sh, shell-config, diagnostics, settings]
requires: [07-01]
provides: [fancy-prompt-modules, avahi-modules, opencode-gsd-module, mouse-reporting-modules, github-token-module, status-check-module, compare-module, upgrade-all-module]
affects: [menu.db (consumer via action_id), modules.sh (pipeline consumer)]
tech-stack:
  added: []
  patterns: [posix-sh-module, metadata-at-key-header, modl-08-param-parsing, marker-based-bashrc-modification, pkg-mgr-auto-detect]
decisions:
  - "Fancy prompt scripts write bash prompt content into ~/.bashrc between marker comments — module scripts are POSIX sh, prompt content is bash syntax"
  - "Prompt content simplified from fu.sh's 300-line templates to compact functional definitions"
  - "Avahi scripts use platform-aware Linux-only paths with macOS Bonjour no-ops"
  - "Mouse reporting uses XTerm-compatible escape sequences (\\033[?1000h / \\033[?1000l)"
  - "set_github_token.sh uses --token param parsing per MODL-08 with fallback to stdin prompt"
key-files:
  created:
    - modules/create_fancy_prompt.sh
    - modules/remove_fancy_prompt.sh
    - modules/create_fancy_prompt_blue.sh
    - modules/remove_fancy_prompt_blue.sh
    - modules/install_avahi.sh
    - modules/remove_avahi.sh
    - modules/install_opencode_gsd.sh
    - modules/configure_mouse_enable.sh
    - modules/configure_mouse_disable.sh
    - modules/set_github_token.sh
    - modules/status_check.sh
    - modules/status_check_compare.sh
    - modules/upgrade_all.sh
  modified: []
metrics:
  duration: "~10 minutes"
  completed-date: "2026-05-25"
---

# Phase 7 Plan 3: Shell Config, Settings, Diagnostics Module Scripts — Summary

Created 13 POSIX sh module scripts covering shell customization (fancy prompts), system configuration (Avahi, mouse reporting), developer tool installation (OpenCode+GSD), settings (GitHub token), and diagnostics (status check, version comparison, batch upgrade). Extracted logic from fu.sh reference implementations — fresh POSIX sh per D-04.

## Completed Tasks

### Task 1: Create shell config and settings module scripts
- **Commit:** `e23547a`
- **Files:** 9 scripts created
- **Result:** Fancy Prompt install/remove (Purple-Pink + Shades of Blue), Avahi install/remove, OpenCode+GSD install, Mouse Reporting enable/disable

### Task 2: Create diagnostics and GitHub token module scripts
- **Commit:** `7c8f1a6`
- **Files:** 4 scripts created
- **Result:** GitHub token storage, Status Check, Compare With Latest, Upgrade All Tools

## What Was Built

**13 POSIX sh module scripts** across 5 functional areas:

| Area | Scripts | Description |
|------|---------|-------------|
| Fancy Prompts | 4 | Purple-Pink and Shades of Blue prompt install/remove via .bashrc marker blocks |
| Hostname Discovery | 2 | Avahi daemon install/remove on Linux; macOS Bonjour no-ops |
| OpenCode+GSD | 1 | npm-based install for OpenCode, GSD (Rokicool), OpenChamber |
| Mouse Reporting | 2 | Terminal escape sequence enable/disable for mouse tracking |
| Settings/Diagnostics | 4 | GitHub token, status check, version comparison, batch upgrade |

### Per-script highlights:

- **create_fancy_prompt.sh / create_fancy_prompt_blue.sh**: Append PS1 definition between `# dev-fu purple-pink prompt start/end` marker comments in ~/.bashrc. Module scripts are POSIX sh; the prompt content written to .bashrc uses bash syntax (which is fine since .bashrc is sourced by bash). Idempotent guard checks for existing markers.

- **remove_fancy_prompt.sh / remove_fancy_prompt_blue.sh**: Remove the marked prompt block from ~/.bashrc using `sed` range deletion with temp-file approach (BSD/macOS compatible). Exit 0 if not installed.

- **install_avahi.sh**: Linux-only — installs avahi-daemon via package manager, enables and starts via systemctl. macOS returns "Bonjour is built-in" and exits 0. Includes full `_pkg_install`/`_pkg_update` helpers.

- **remove_avahi.sh**: Stops and disables avahi-daemon systemd service, removes packages. Includes `_pkg_remove` helper. macOS: "Bonjour cannot be removed."

- **install_opencode_gsd.sh**: Checks npm availability, then installs each missing component (OpenCode, GSD, OpenChamber) individually. Tracks error count across components.

- **configure_mouse_enable.sh / configure_mouse_disable.sh**: Send `\033[?1000h` / `\033[?1000l` escape sequences to enable/disable XTerm-compatible mouse tracking. Minimal, single-line implementations.

- **set_github_token.sh**: MODL-08 `--token` param parsing (`while [ $# -gt 0 ]; do case "$1" in --token)...`). Falls back to `read -r` prompt if no `--token` provided. Saves to `~/.config/dev-fu/github-token` with `chmod 600` (threat mitigation T-07-07). Validates token against GitHub API.

- **status_check.sh**: Checks 26+ tools across 3 categories (Languages & Runtimes, Tools, Utilities) using `command -v` + version flag. Includes system info header. Sources NVM for accurate Node.js detection.

- **status_check_compare.sh**: Compares installed vs latest versions using GitHub API, npm registry, PyPI, and other online sources. Uses authenticated API calls when token is present. Graceful fallback on network errors. Outputs table with up-to-date/update-available status.

- **upgrade_all.sh**: Batch upgrades all installed tools. Handles Docker, Go (pkg mgr), Rust (rustup), Node.js (NVM + nvm install --lts), Bun (bun upgrade), Python (pip/pipx/uv), PHP, Yarn (npm), Tailscale, OpenCode (npm), GSD (npx), OpenChamber (npm). Skips uninstalled tools. Reports success/failure count.

## Verification

All acceptance criteria met:

- 13 scripts exist: `ls modules/{create,remove,install,configure,set,status,upgrade}*.sh | wc -l` = 13 ✓
- All scripts have `@name`: ✓ (each confirmed with head -8 | grep)
- All scripts have `@platforms` and `@version`: ✓
- Fancy prompt marker comments: `grep -l 'dev-fu.*prompt' modules/*fancy*.sh | wc -l` = 4 ✓
- set_github_token.sh MODL-08 parsing: `--token` param parsed with case/esac ✓
- chmod 600 on token file: ✓ (threat T-07-07 mitigated)
- status_check.sh uses command -v: 6 counts ✓
- status_check_compare.sh has @name: ✓
- upgrade_all.sh uses rustup update + npm update -g: ✓
- No bashisms in module scripts (heredoc prompt content excluded — by design): ✓
- All action IDs from menu.db for these tools have corresponding module scripts: ✓

## Deviations from Plan

None — plan executed exactly as written.

### Implementation notes (non-deviations):
- Remove scripts use variable-based marker references (`${MARKER_START}`) instead of literal strings in sed commands — better maintainability, same functionality
- Fancy prompt content simplified from fu.sh's 300+ line templates to compact, functional prompt definitions — still uses purple-pink and blue color schemes as specified
- `_pkg_remove` helper added to remove_avahi.sh (not specified in plan but needed for correct operation — Rule 2 pattern)

## Known Stubs

None — all scripts are fully implemented with working logic.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: token-storage | set_github_token.sh | Writes GitHub token to ~/.config/dev-fu/github-token with chmod 600 — per T-07-07 mitigation |
| threat_flag: npm-global-install | install_opencode_gsd.sh | Uses npm install -g — depends on npm registry integrity per T-07-08 (accept disposition) |
| threat_flag: bashrc-modification | create_fancy_prompt.sh, create_fancy_prompt_blue.sh | Writes to ~/.bashrc between marker comments — per T-07-08 mitigation; uses isolated blocks for safe removal |
| threat_flag: external-api | status_check_compare.sh, upgrade_all.sh | Calls GitHub API, npm, PyPI, and other external services — per T-07-10 (accept disposition with graceful fallback) |

## Self-Check: PASSED

- All 13 scripts exist ✓
- All scripts have valid metadata headers ✓
- Commit `e23547a` exists (Task 1: 9 shell config scripts) ✓
- Commit `7c8f1a6` exists (Task 2: 4 diagnostics scripts) ✓
