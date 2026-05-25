---
phase: 07-feature-parity
plan: 01
subsystem: menu
tags: [menu.db, action-id, registry, contract, documentation]
requires: []
provides: [menu-database-v1.1, action-id-convention, module-contract]
affects: [menu.sh (consumer), modules.sh (consumer), plans 07-02, 07-03 (downstream specs)]
decisions:
  - "D-01: 6 functional categories with submenus — Diagnostics, Languages & Runtimes, Tools, Shell, Settings"
  - "D-02: Emoji-prefixed labels matching fu.sh visual conventions on every 3rd field"
  - "D-07: Install/remove entries as separate action IDs — install_<tool> / remove_<tool>"
  - "D-09: No remove action for OpenCode+GSD (single-action install only)"
  - "configure_mouse_* naming for mouse reporting (fu.sh has no POSIX equivalent)"
tech-stack:
  added: []
  patterns: [pipe-delimited-menu-dsl, action-id-as-filename, metadata-at-key-header]
key-files:
  created: [modules/README.md]
  modified: [menu.db]
metrics:
  duration: "~5 minutes"
  completed-date: "2026-05-25"
---

# Phase 7 Plan 1: Menu Database Expansion — Summary

Replaced the 12-item demo menu.db with the v1.1 menu covering all 18 fu.sh operations across 6 functional categories with emoji-prefixed labels, and documented the action ID naming convention and module script contract.

## Completed Tasks

### Task 1: Write the expanded menu.db with all 18 fu.sh operations
- **Commit:** `0d83ad8`
- **File:** `menu.db` (59 line delta: 44 insertions, 15 deletions)
- **Result:** 31 data entries across 6 categories

### Task 2: Create modules/README.md with action ID registry and module contract
- **Commit:** `2385115`
- **File:** `modules/README.md` (130 lines, new)
- **Result:** Complete 31-entry registry, metadata header spec, env var reference, runtime contract, naming conventions, fu.sh line-number mapping

## What Was Built

**menu.db v1.1** — 31 entries organizing all fu.sh operations into 6 functional categories:

| Category | Subcategories | Entries |
|----------|--------------|---------|
| Diagnostics | System, Updates | 3 |
| Languages & Runtimes | Go, Rust, Python, Node.js, Bun, PHP | 12 |
| Tools | Yarn, Docker, Tailscale, OpenCode | 7 |
| Shell | Prompts, Network | 6 |
| Settings | GitHub, Mouse | 3 |

Every entry uses `Category|Subcategory|Label|action_id` format (4 pipe-delimited fields). Install/remove pairs use distinct action IDs. No action ID contains non-ASCII characters.

**modules/README.md** — Canonical reference for Plans 07-02 and 07-03:
- 31-entry action ID registry table (mapping each action_id to script filename, tool name, and operation type)
- Module metadata header contract: `@name`, `@params`, `@platforms`, `@version`, `@deps`, `@timeout`
- FLU_* environment variable reference (7 vars)
- Runtime contract: `set -eu`, auto-detect fallback for FLU_PKG_MGR, idempotent installs, safe removes
- Naming conventions: `install_<tool>.sh`, `remove_<tool>.sh`, `create_<thing>.sh`, etc.
- fu.sh line-number reference mapping for all 28 modules with existing fu.sh implementations
- Notes on 3 modules with no direct fu.sh equivalent (`remove_php_laravel`, `configure_mouse_disable`, `configure_mouse_enable`)

## Verification

All acceptance criteria met:

- menu.db: 31 data lines (≥ 30), exactly 4 fields per line, no non-ASCII in action IDs
- Category counts: Diagnostics≥3, Languages&Runtimes≥12, Tools≥7, Shell≥6, Settings≥3 ✓
- Specific action IDs verified: install_go, remove_go, install_docker, install_opencode_gsd, upgrade_all, status_check, configure_mouse_enable — all present once
- No remove_opencode_gsd entry (per D-09) ✓
- modules/README.md: Action ID Registry, Module Script Contract, fu.sh Reference Mapping, naming conventions all present
- Runtime contract: set -eu (1), FLU_PKG_MGR (3) documented ✓
- No stubs or placeholders ✓

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no hardcoded empty values, placeholder text, or disconnected data sources.

## Threat Flags

None — menu.db is a data file (git-tracked, awk-parsed, no eval), README.md is documentation only. Threat model T-07-01 (Tampering) and T-07-02 (Spoofing) both accept disposition.

## Self-Check: PASSED

- `menu.db` exists with 31 data lines ✓
- `modules/README.md` exists (130 lines) ✓
- Commit `0d83ad8` exists (task 1: menu.db expansion) ✓
- Commit `2385115` exists (task 2: action ID registry) ✓
