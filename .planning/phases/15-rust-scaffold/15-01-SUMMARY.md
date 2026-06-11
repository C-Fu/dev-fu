---
phase: 15-rust-scaffold
plan: 01
subsystem: cli
tags: [rust, clap, serde, cargo, platform-detection, menu-parser, include-str]

# Dependency graph
requires: []
provides:
  - "fust Rust binary with CLI parsing matching flu.sh flags"
  - "Platform detection producing identical results to flu.sh FLU_* variables"
  - "menu.db parser with table and JSON output"
  - "Embedded menu.db at compile time via include_str!"
affects: [16-tui, 17-interactive-menus, 18-module-pipeline, 19-registry-batch]

# Tech tracking
tech-stack:
  added: [rust-1.95, clap-v4-derive, serde-v1, serde-json-v1, anyhow-v1]
  patterns: [clap-derive-cli, include-str-compile-time-embedding, serde-rename-json-keys, platform-detection-via-std-env]

key-files:
  created:
    - fust/Cargo.toml
    - fust/src/main.rs
    - fust/src/cli.rs
    - fust/src/platform.rs
    - fust/src/menu.rs
    - fust/.gitignore
  modified: []

key-decisions:
  - "clap v4 derive for CLI parsing — idiomatic Rust, auto-generates help and version"
  - "include_str! for compile-time menu.db embedding — zero runtime file dependency"
  - "serde rename label→name for JSON field matching flu.sh output format"
  - "Platform detection via std::env::consts + sh -c subprocess for distro/pkg_mgr — matches flu.sh exactly"

patterns-established:
  - "Module-per-file pattern: cli.rs, platform.rs, menu.rs — each with its own #[cfg(test)]"
  - "Compile-time data embedding: include_str! for static assets (menu.db)"
  - "CLI dispatch in main.rs: parse → detect platform → route to module → output"

requirements-completed: []

# Metrics
duration: 5min
completed: 2026-06-11
---

# Phase 15 Plan 01: Rust Project Scaffold + CLI Summary

**Clap v4 CLI with 5 flags matching flu.sh, platform detection via std::env/sh subprocess, and compile-time embedded menu.db parser with table/JSON output**

## Performance

- **Duration:** 5 min
- **Started:** 2026-06-11T07:13:39Z
- **Completed:** 2026-06-11T07:19:15Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Built working `fust` binary from scratch — `cargo build` produces debug binary
- CLI flags (`--install`, `--remove`, `--list`, `--yes`, `--json`) match flu.sh help text exactly
- Platform detection produces identical output to flu.sh's `flu_module_set_env()` on the same system
- menu.db embedded at compile time, parsed into sorted entries with table and JSON output
- 13 passing tests covering platform detection and menu parsing

## Task Commits

Each task was committed atomically:

1. **task 1: Cargo project scaffold + CLI parsing + platform detection** - `f6167f7` (feat)
2. **task 2: menu.db parser + --list table/JSON output** - `8f4fb8f` (feat)

**Plan metadata:** pending (docs commit follows)

## Files Created/Modified
- `fust/Cargo.toml` — Project manifest with clap, serde, serde_json, anyhow dependencies
- `fust/src/main.rs` — Entry point with CLI dispatch to list/batch/TUI modes
- `fust/src/cli.rs` — Clap v4 derive CLI struct with 5 flags matching flu.sh
- `fust/src/platform.rs` — Platform detection (os, distro, pkg_mgr, arch, wsl, termux, root)
- `fust/src/menu.rs` — menu.db parser, table formatter, JSON serializer with 9 tests
- `fust/.gitignore` — Excludes /target build artifacts

## Decisions Made
- Used clap v4 derive — idiomatic Rust, auto-generates `--help` and `--version` from struct attributes
- Used `include_str!("../../menu.db")` for compile-time embedding — no runtime file dependency
- Used `serde(rename = "name")` on label field to match flu.sh JSON output format
- Platform detection uses `std::env::consts::OS` for OS and `sh -c` subprocess calls for distro/pkg_mgr to exactly match flu.sh behavior
- Malformed menu.db lines silently skipped (T-15-02 mitigation) — wrong field count is ignored

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- fust binary builds and runs on Linux (current platform)
- CLI parsing, platform detection, and menu listing all functional
- Ready for Phase 16 (TUI rendering) — `menu.rs` provides the data layer, main.rs has TUI stub
- Ready for Phase 17 (interactive menus) — menu entries parsed and sorted
- Ready for Phase 18 (module pipeline) — platform detection provides FLU_* equivalent context
- Portability note: code uses conditional `/proc/version` reads (graceful on macOS), no platform-specific compilation

---
*Phase: 15-rust-scaffold*
*Completed: 2026-06-11*
