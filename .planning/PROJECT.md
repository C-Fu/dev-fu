# dev-fu / flu.sh

## What This Is

A cross-platform environment setup utility that installs, configures, and manages developer tools via an interactive terminal menu. The existing `fu.sh` (Bash) and `fu.ps1` (PowerShell) are monolithic single-file scripts. This milestone creates `flu.sh` — a modular, menu-driven successor with a portable lxdialog-style TUI, nested submenus, and a remote module architecture. Both scripts coexist: `fu.sh` remains the simple/legacy version, `flu.sh` is the feature-rich modular system.

## Core Value

A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## Requirements

### Validated

- ✓ Cross-platform platform detection (Linux, macOS, WSL2, Windows) — existing
- ✓ Multi-package-manager abstraction (apt, apk, dnf, pacman, zypper, brew, winget, choco) — existing
- ✓ Interactive numbered menu with install/remove operations — existing (`fu.sh`)
- ✓ CLI mode for non-interactive execution (e.g. `bash fu.sh 5 -9`) — existing
- ✓ 18 install/remove operations for dev tools (Docker, Go, Rust, Node, Python, etc.) — existing
- ✓ Fancy prompt installation (Purple-Pink, Shades of Blue) — existing
- ✓ Status check and version comparison against latest upstream — existing
- ✓ GitHub token support for higher API rate limits — existing
- ✓ Upgrade-all batch operation — existing
- ✓ PowerShell full port (`fu.ps1`) — existing
- ✓ POSIX sh checklist widget (`checklist.sh`) — existing
- ✓ TTY reattachment for curl-pipe-bash usage — existing
- ✓ sudo detection and validation — existing

### Active

- [ ] Portable lxdialog-style TUI engine in pure ANSI/ASCII (checklist, multi-select, cursor navigation, zero dependencies)
- [ ] `flu.sh` script with 3-level nested submenu support (Menu → Category → Option → Sub-option)
- [ ] Modular remote script architecture — each menu option fetches and executes a standalone script from GitHub on demand
- [ ] Variable passing to module scripts via inline prompts (e.g. flu.sh → "Install GSD" → asks global/local → calls `install_gsd.sh --global`)
- [ ] PowerShell parity for all flu.sh features in `fu.ps1`
- [ ] POSIX shell compatibility (bash, zsh, ash, dash, busybox sh) for flu.sh
- [ ] Git branch `flu.sh` for development, merge to `main` when stable

### Out of Scope

- GUI or web-based interface — terminal only, that's the identity
- Package creation/publishing — this is a setup utility, not a package manager
- Auto-update mechanism for flu.sh itself — manual curl-pipe-bash or git pull
- Configuration file / state persistence between runs — stateless design
- Localization beyond existing README translations — English only for now

## Context

- Existing codebase: `fu.sh` (2629 lines Bash), `fu.ps1` (1971 lines PowerShell), `checklist.sh` (596 lines POSIX sh)
- `checklist.sh` already has a working POSIX multi-select widget with Fish shell support — this is a foundation for the lxdialog engine
- Current architecture is monolithic: all install logic is inline in fu.sh. The new modular design extracts each option into its own remote script.
- The project is curl-pipe-bash friendly (`curl | bash fu.sh`) — this must be preserved
- Existing scripts detect and adapt to: Linux distros, macOS, WSL2, Chromebook containers, Termux, Alpine (musl)

## Constraints

- **POSIX Compliance**: flu.sh must work on bash, zsh, ash, dash, busybox sh — no Bash-only features in core menu logic (lxdialog engine must be POSIX)
- **Zero Dependencies**: No external tools required beyond what a minimal OS provides (curl/wget for remote fetch)
- **PowerShell Parity**: fu.ps1 must have the same menu structure, modules, and features
- **Remote-Only Modules**: Module scripts are fetched on-demand from GitHub raw URLs, not bundled locally
- **Pure ANSI/ASCII UI**: No dialog, whiptail, ncurses, or other TUI libraries — all rendering via terminal escape codes

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| flu.sh coexists with fu.sh (not a replacement) | fu.sh is simple and battle-tested; flu.sh is the feature-rich version | — Pending |
| Pure ANSI/ASCII for lxdialog (no dialog/whiptail fallback) | Maximum portability — works in minimal containers, Termux, embedded | — Pending |
| 3-level max submenu depth | Covers Menu → Category → Option → Sub-option without unbounded complexity | — Pending |
| Remote on-demand module fetching | Single-file curl-pipe deployment, modules stay up-to-date independently | — Pending |
| Inline prompts for variables (not dialog popups) | Consistent with existing fu.sh UX, simpler to implement cross-shell | — Pending |
| Branch `flu.sh` for development | Isolated development, merge to main when validated | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-23 after initialization*
