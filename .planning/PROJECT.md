# dev-fu / flu.sh

## What This Is

A cross-platform environment setup utility that installs, configures, and manages developer tools via an interactive terminal menu. `fu.sh` (Bash) and `fu.ps1` (PowerShell) are battle-tested monolithic scripts. `flu.sh` and `flu.ps1` are the next-generation modular TUI systems with nested submenus, breadcrumb navigation, and on-demand module fetching. All scripts coexist: `fu.sh` is the legacy workhorse, `flu.sh` is the feature-rich modular system.

## Core Value

A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## Current Milestone: v1.1 Feature Parity & Polish

**Goal:** flu.sh reaches full feature parity with fu.sh (all 18 operations), gets a polished intro screen, and README restructuring makes flu.sh the primary project face.

**Target features:**
- Prettier flu.sh intro screen reusing the big ASCII dev-fu logo with platform info
- Extend menu.db with all 18 fu.sh menu options
- Create module scripts for each new menu item (Docker, Go, Rust, Bun, etc.)
- Restructure README — move fu.sh docs to README-Fu.md, create flu.sh-focused README

## Requirements

### Validated

- ✓ Cross-platform platform detection — v1.0
- ✓ Multi-package-manager abstraction (8 managers) — v1.0
- ✓ Interactive numbered menu with install/remove — existing (`fu.sh`)
- ✓ CLI mode for non-interactive execution — existing
- ✓ 18 install/remove operations for dev tools — existing (`fu.sh`)
- ✓ Fancy prompt installation — existing
- ✓ Status check and version comparison — existing
- ✓ GitHub token support — existing
- ✓ Upgrade-all batch operation — existing
- ✓ PowerShell port (`fu.ps1` / `flu.ps1`) — v1.0
- ✓ POSIX sh checklist widget (`checklist.sh`) — existing
- ✓ TTY reattachment for curl-pipe-bash — v1.0
- ✓ sudo detection and validation — existing
- ✓ Portable TUI engine (2261 lines) — v1.0 Phase 1
- ✓ 3-level nested submenu with breadcrumbs — v1.0 Phase 3
- ✓ Modular remote script architecture — v1.0 Phase 4
- ✓ Inline prompts for module script parameters — v1.0 Phase 4
- ✓ PowerShell parity for all TUI features in `flu.ps1` — v1.0 Phase 6
- ✓ POSIX shell compatibility (bash, zsh, ash, dash, busybox) — v1.0
- ✓ flu.sh development branch — v1.0 Phase 5

### Active

- [ ] flu.sh feature parity — all 18 fu.sh options available in the TUI menu
- [ ] Module scripts for each tool (Docker, Go, Rust, Bun, NVM, PHP, Tailscale, etc.)
- [ ] Prettier flu.sh intro screen with dev-fu ASCII logo
- [ ] Restructured README — flu.sh as primary, fu.sh docs in README-Fu.md

### Out of Scope

- GUI or web-based interface — terminal only
- Package creation/publishing — this is a setup utility, not a package manager
- Auto-update for flu.sh — manual curl-pipe-bash or git pull
- Configuration file / state persistence — stateless design
- Localization beyond README translations — English only

## Context

- Shipped v1.0 with 7,442 LOC across POSIX shell (4,266) and PowerShell (3,176)
- 6 phases, 17 plans completed in ~11 hours
- Full TUI engine, menu system, module pipeline, and orchestrator working
- flu.sh currently has 12 demo menu items — needs expansion to match fu.sh's 18 options
- Module scripts exist as stubs — need real install logic extracted from fu.sh

## Constraints

- **POSIX Compliance**: No bashisms in core logic (shellcheck -s sh enforcement)
- **Zero Dependencies**: curl/wget are the only external network tools
- **PowerShell Parity**: flu.ps1 mirrors flu.sh features
- **Remote-Only Modules**: Module scripts fetched on-demand from GitHub raw URLs
- **Pure ANSI/ASCII UI**: No dialog, whiptail, ncurses

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| flu.sh coexists with fu.sh (not a replacement) | fu.sh is simple and battle-tested; flu.sh is the feature-rich version | ✓ Good |
| Pure ANSI/ASCII for TUI | Maximum portability in minimal containers, Termux, embedded | ✓ Good |
| 3-level max submenu depth | Menu → Category → Option without unbounded complexity | ✓ Good |
| Remote on-demand module fetching | Single-file curl-pipe deployment, modules independently updatable | ✓ Good |
| Inline prompts for variables | Consistent with fu.sh UX, simpler cross-shell | ✓ Good |
| flu.sh branch for development | Isolated development, merge to main when validated | ✓ Good |
| Source+function API for subsystems | Library-first design, demo-second — all subsystems sourceable | ✓ Good |
| Pipe-delimited menu DSL with awk | Same parsing pattern as menu.db, zero dependencies | ✓ Good |

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
*Last updated: 2026-05-25 — v1.1 milestone start*
