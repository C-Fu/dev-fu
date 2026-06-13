# Phase 15: Rust Project Scaffold + CLI — Context

**Status:** LOCKED
**Branch:** `fust`
**Date:** 2026-06-11

## Goal

Bootstrap the `fust` Rust project inside the dev-fu repo. Produce a working binary with CLI argument parsing and platform detection that mirrors flu.sh's interface.

## Decisions

### D-01: Binary name is `fust`
- Compiled binary: `fust`
- Command: `fust --install go`, `fust --list`, etc.
- Install path: `~/.local/bin/fust` (or `/usr/local/bin/fust`)
- Rationale: Short, unique, distinct from `flu.sh` shell script. Avoids collision with existing tools.

### D-02: Hybrid module execution model
- **Core modules** → Rewritten as native Rust functions (cross-platform, no shell dependency)
  - Core = most common, cross-platform actions (e.g., install common tools, configure dotfiles)
  - Builder determines exact classification; criteria: runs on 3+ platforms, high usage frequency
- **Shell fallback modules** → Original shell scripts embedded via `include_str!()` at compile time, exec'd via `sh -c`
  - Platform-specific or complex modules that are low-value to rewrite
  - Still requires `sh` on target system for these modules (acceptable — POSIX guaranteed)
- **Community modules** → Fetched from registry at runtime (Phase 19 scope)
- Module type is tagged in the module manifest so the runtime knows which path to take

### D-03: Project location is `fust/` subdirectory
- Rust project lives at `<repo-root>/fust/`
- Contains standard Cargo project: `Cargo.toml`, `src/`, `tests/`
- Shell scripts (`flu.sh`, `tui.sh`, etc.) remain at repo root — they coexist
- `menu.db` stays at repo root; Rust binary embeds it via `include_str!("../menu.db")` or similar

### D-04: CLI flags (carried from Phase 12)
- `--install <ids>` — Run specific module actions by ID
- `--remove <ids>` — Uninstall specific module actions
- `--list` — Show full menu/module listing
- `--list --json` — Machine-readable listing
- `--yes` — Skip all confirmation prompts
- `--help` — Usage info
- `--version` — Print version
- No arguments → Launch interactive TUI (Phase 16 scope, but CLI parser must support it)

### D-05: Platform detection mirrors flu.sh
- Detect: OS family, distro name, package manager, CPU architecture
- Store as struct fields (replaces flu.sh's `FLU_OS`, `FLU_DISTRO`, `FLU_PKG_MGR`, `FLU_ARCH`)
- Must produce identical results to current shell detection on same system

## Carried Forward

- From Phase 12 D-02: Users pass exact action_ids (e.g., `install_go`)
- From Phase 12 D-04: Minimal flag set (no subcommands yet)
- From PROJECT.md: Zero runtime dependencies (for core path), curl-pipe-bash installer

## Builder Discretion

- CLI parsing framework (clap derive vs manual — clap v4 derive recommended)
- Which modules are "core" vs "shell fallback" — define criteria and initial classification
- Rust edition, MSRV, feature flags structure
- Error handling strategy (anyhow, thiserror, custom)
- Log/verbosity approach (tracing, log crate, or simple)
- Test framework and test structure
- How `menu.db` is referenced at compile time (include_str path, build script copy, etc.)

## Out of Scope

- TUI rendering (Phase 16)
- Interactive menu navigation (Phase 17)
- Module pipeline internals (Phase 18)
- Registry/batch execution (Phase 19)
- Build/release pipeline (Phase 21)
- Migrating users from flu.sh to fust (Phase 20 integration)

## Success Criteria

1. `cargo build` in `fust/` produces a `fust` binary
2. `fust --help` displays all flags from D-04
3. `fust --list` outputs menu categories/actions from embedded `menu.db`
4. `fust --version` prints version from Cargo.toml
5. Platform detection sets OS, distro, package manager, arch (matching flu.sh output)
6. `cargo test` passes
7. Binary runs on Linux and macOS (cross-compilation setup is Phase 21, but code must be portable)
