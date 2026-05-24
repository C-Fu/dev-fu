# Phase 4 Discussion Log

**Date:** 2026-05-25
**Phase:** 04-module-architecture

## Areas Discussed

### 1. Module script format & metadata

**Q: What metadata format should module scripts use?**
Options: Comment-block header (awk-parseable), Convention-based comments, Manifest file
**→ Selected: Comment-block header (awk-parseable)**
@key: value syntax, parsed with awk, same pattern as menu.db DSL.

**Q: Where do module scripts live on GitHub?**
Options: Single dedicated module repo, Configurable base URL
**→ Selected: Single dedicated module repo**
`flu-modules` repo under `modules/<action_id>.sh` path.

**Q: What metadata fields should each module declare?**
Options: Minimum (name, args, platforms), Parameter declarations, Rich
**→ Selected: Rich: name, args, platforms, version, deps, timeout**
Fields: @name, @params (type+choices), @platforms, @version, @deps, @timeout.

### 2. Fetch strategy & error handling

**Q: How should modules be fetched and executed?**
Options: Download-then-execute, Pipe-to-sh
**→ Selected: Pipe-to-sh (curl-pipe-bash style)**

**Q: Fetch caching and error handling approach?**
Options: No caching, Cache with TTL, Retry 3x with spinner, Single attempt
**→ Selected: No caching — fetch fresh every time**
Error handling: retry 3 times with 2-second delay, spinner during fetch, clear error on failure.

### 3. Parameter collection & execution flow

**Q: What's the execution flow?**
Options: Fetch→parse→prompt→execute→results, Inline TUI, Sequential
**→ Selected: Fetch → parse metadata → prompt → pipe+execute → results**

**Q: How should platform context reach module scripts?**
Options: Env vars from fu.sh patterns, Minimal curated env vars, CLI args
**→ Selected: Env vars from fu.sh detection patterns**
FLU_OS, FLU_DISTRO, FLU_PKG_MGR, FLU_ARCH, FLU_IS_WSL, FLU_IS_TERMUX, FLU_IS_ROOT.

### 4. Module output, security & sandboxing

**Q: How should module execution results be displayed?**
Options: Stdout inline with banner, Box-rendered result modal, Simple colored text
**→ Selected: Box-rendered result modal (matching TUI style)**

**Q: Module execution isolation and safety?**
Options: Subshell with timeout, Strict mode
**→ Selected: Strict mode: set -euo pipefail + EXIT trap**

## Deferred Ideas
- Module caching with TTL — MODL-07 (v2)
- SHA256 checksum verification — MODL-08 (v2)
- Module registry with auto-discovery — MODL-06 (v2)
- Module execution logging to file — INTG-10 (v2)
- CLI batch mode — INTG-06 (v2)

## OpenCode's Discretion
- Exact @param syntax and parser implementation
- @deps resolution order and cycle detection
- Spinner rendering implementation
- Exact recovery hint wording per error pattern
- Timeout mechanism (background process + kill)
- Module metadata parser function name and internal variable naming
- Action ID → GitHub URL mapping approach
