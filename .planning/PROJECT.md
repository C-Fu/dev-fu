# dev-fu / flu.sh

## What This Is

A cross-platform environment setup utility that installs, configures, and manages developer tools via an interactive terminal menu. `fu.sh` (Bash) and `fu.ps1` (PowerShell) are battle-tested monolithic scripts. `flu.sh` and `flu.ps1` are the next-generation modular TUI systems with nested submenus, breadcrumb navigation, and on-demand module fetching. All scripts coexist: `fu.sh` is the legacy workhorse, `flu.sh` is the feature-rich modular system.

## Core Value

A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## Current State

**Shipped:** v1.1 Feature Parity & Polish (2026-05-25)
**Total LOC:** 7,766 across flu.sh core (4,414) + 46 module scripts (3,352)
**Next:** v2.0 Modular Ecosystem

## Current Milestone: v2.0 Modular Ecosystem

**Goal:** Transform flu.sh from a functional TUI into a production-grade modular ecosystem — hardened module pipeline, modern CLI tool suite, and cross-platform PowerShell parity.

**Target features:**
- SHA256 checksums for fetched module scripts (security)
- Module caching with TTL (performance)
- CLI batch mode for non-interactive execution
- Module registry with auto-discovery
- Color themes via FLU_THEME env var
- Progress bar for downloads
- Module execution logging
- Terminal resize handling
- Modern CLI tools: lazygit, starship, zoxide, eza
- PowerShell parity update (flu.ps1 mirrors all v1.1 + v2.0 changes)

## Requirements

### Validated

- ✓ Cross-platform platform detection — v1.0
- ✓ Multi-package-manager abstraction (8 managers) — v1.0
- ✓ Interactive numbered menu with install/remove — v1.0
- ✓ CLI mode for non-interactive execution — v1.0
- ✓ 18 install/remove operations for dev tools — v1.0
- ✓ Fancy prompt installation — v1.0
- ✓ Status check and version comparison — v1.0
- ✓ GitHub token support — v1.0
- ✓ Upgrade-all batch operation — v1.0
- ✓ PowerShell port (`fu.ps1` / `flu.ps1`) — v1.0
- ✓ POSIX sh checklist widget (`checklist.sh`) — v1.0
- ✓ TTY reattachment for curl-pipe-bash — v1.0
- ✓ sudo detection and validation — v1.0
- ✓ Portable TUI engine (2261 lines) — v1.0
- ✓ 3-level nested submenu with breadcrumbs — v1.0
- ✓ Modular remote script architecture — v1.0
- ✓ Inline prompts for module script parameters — v1.0
- ✓ PowerShell parity for all TUI features in `flu.ps1` — v1.0
- ✓ POSIX shell compatibility (bash, zsh, ash, dash, busybox) — v1.0
- ✓ flu.sh development branch — v1.0
- ✓ flu.sh feature parity — all 18 fu.sh options in TUI menu — v1.1
- ✓ 46 module scripts with real install/remove logic — v1.1
- ✓ ASCII dev-fu logo with platform info on startup — v1.1
- ✓ README restructured — flu.sh primary, fu.sh in README-Fu.md — v1.1
- ✓ Bahasa Melayu translations with bidirectional cross-references — v1.1

### Active

- [ ] SHA256 checksum verification for fetched module scripts
- [ ] Module caching with TTL to avoid re-fetching
- [ ] CLI batch mode for non-interactive execution
- [ ] Module registry with auto-discovery
- [ ] Color themes via FLU_THEME env var
- [ ] Progress bar for downloads
- [ ] Module execution logging
- [ ] Terminal resize handling
- [ ] Modern CLI tools: lazygit, starship, zoxide, eza
- [ ] PowerShell parity update for flu.ps1

### Out of Scope

- GUI or web-based interface — terminal only
- Package creation/publishing — this is a setup utility, not a package manager
- Auto-update for flu.sh — manual curl-pipe-bash or git pull
- Configuration file / state persistence — stateless design
- Localization beyond README translations — English only
- New tools not in fu.sh — feature parity milestone complete; new tools for future milestones
- flu.ps1 feature parity update — PowerShell port already complete at parity

## Context

- Shipped v1.0 (7,442 LOC) and v1.1 (+46 module scripts, 7,766 total LOC)
- v1.0: 6 phases, 17 plans in ~11 hours
- v1.1: 3 phases, 7 plans in 1 day
- Full TUI engine, menu system, module pipeline, orchestrator, intro screen, and docs
- 31 menu entries across 5 categories, 46 module scripts covering all 18+ tools
- All READMEs restructured with Bahasa Melayu translations

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
| flu.sh branch retired; modules served from `main/flu-sh/modules/` | Eliminated dual-branch maintenance and merge conflicts; `fust` and `flu.sh` fetch from main | ✓ Updated |
| Source+function API for subsystems | Library-first design, demo-second — all subsystems sourceable | ✓ Good |
| Pipe-delimited menu DSL with awk | Same parsing pattern as menu.db, zero dependencies | ✓ Good |
| 6-category menu grouping (later 5) | Groups 31 entries into logical navigation tiers | ✓ Good |
| Standardized module contract (`set -eu`, `_maybe_sudo()`, FLU_PKG_MGR) | Consistent pattern across all 46 module scripts | ✓ Good |
| Menu.db as authoritative source for docs | Single source of truth, README matches menu exactly | ✓ Good |
| Plain-text fallback for ASCII logo | POSIX compatibility in non-TUI terminals | ✓ Good |

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
*Last updated: 2026-05-28 — v2.0 milestone start*
