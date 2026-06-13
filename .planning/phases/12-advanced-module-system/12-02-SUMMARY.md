---
phase: 12-advanced-module-system
plan: 02
subsystem: modules
tags: [registry, community-modules, json, awk, sha256, caching, posix-sh]

# Dependency graph
requires:
  - phase: 12-01
    provides: flu_batch_run, flu_batch_list, CLI dispatch, action_id validation
provides:
  - "flu_registry_fetch(): fetch and cache community module registry JSON with TTL"
  - "flu_registry_lookup(): look up module in registry by action_id, set global fields"
  - "flu_registry_fetch_module(): fetch community module with SHA256 verification"
  - "Dynamic 'Community Modules' top-level menu category in TUI"
  - "FLU_REGISTRIES env var for merging third-party registries"
  - "community/<action_id> namespace preventing shadowing of official modules"
affects: [powershell-parity]

# Tech tracking
tech-stack:
  added: []
  patterns: [awk-json-parsing, registry-merge-sed, community-namespace-prefix, dynamic-menu-assembly]

key-files:
  created: []
  modified:
    - modules.sh
    - flu.sh

key-decisions:
  - "Community modules delegated to separate fetch pipeline (flu_registry_fetch_module) instead of modifying official MANIFEST.sha256 path"
  - "Awk parses JSON using line copies (_l = $0) to avoid $0 mutation breaking subsequent pattern matching"
  - "FLU_REGISTRIES merge uses sed bracket stripping + comma join (not awk re-parse) for robustness with both compact and pretty-printed JSON"
  - "Dynamic menu assembly via temp merged file rather than modifying menu.sh internals"

patterns-established:
  - "Registry pipeline: fetch → cache with TTL → lookup → fetch module → SHA256 verify → cache module"
  - "Namespace prefix pattern: community/<id> prevents official module shadowing (D-14)"
  - "Temp menu assembly: cat menu.db + awk-extracted community entries → merged file → FLU_MENU_FILE"

requirements-completed: [ADVN-02]

# Metrics
duration: 15min
completed: 2026-05-28
---

# Phase 12 Plan 02: Module Registry Summary

**Community module registry with GitHub-hosted JSON index, awk-based parsing, SHA256 verification, FLU_REGISTRIES merge, and dynamic TUI menu injection under 'Community Modules' category**

## Performance

- **Duration:** 15 min
- **Started:** 2026-05-27T20:21:59Z
- **Completed:** 2026-05-28T11:11:14Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- `flu_registry_fetch()` — fetches and caches registry JSON with TTL, merges FLU_REGISTRIES env var URLs, soft-fail per registry
- `flu_registry_lookup()` — parses registry JSON with awk, extracts 6 fields (name, description, category, platforms, base_url, sha256) into globals
- `flu_registry_fetch_module()` — fetches community module from registry URL with 3-retry, SHA256 verification, and cache storage
- `flu_module_resolve_url()` updated to handle `community/*` namespace via registry delegation
- `flu_module_fetch()` delegates community modules to registry fetch pipeline (separate from official MANIFEST.sha256 path)
- `flu_batch_list()` includes community modules with `community/` prefix in both table and JSON output
- `flu_batch_run()` skips menu.db validation for `community/*` action_ids
- Dynamic menu assembly in flu.sh: merges menu.db + registry entries into temp file, cleaned up on exit
- Registry fetch failure is non-blocking — TUI shows official modules only with warning

## Task Commits

Each task was committed atomically:

1. **Task 1: Registry fetch/cache/lookup infrastructure in modules.sh** - `6a2b6f5` (feat)
2. **Task 2: Dynamic community modules menu category and startup integration** - `c713154` (feat)
3. **Task 3: End-to-end integration test and edge case hardening** - `26da7b2` (fix)

## Files Created/Modified

- `modules.sh` — Added Sections 12-14 (flu_registry_fetch, flu_registry_lookup, flu_registry_fetch_module), modified flu_module_resolve_url, flu_module_fetch, flu_batch_list, flu_batch_run for community module support
- `flu.sh` — Added registry pre-fetch, dynamic menu assembly, temp file cleanup in trap and normal exit

## Decisions Made

- **Separate fetch pipeline for community modules:** Rather than modifying the official MANIFEST.sha256 verification path to handle both official and community modules, community modules get their own `flu_registry_fetch_module()` function. This keeps the official pipeline unchanged and makes the two security models (MANIFEST.sha256 vs registry-provided sha256) cleanly separated.
- **Line copies in awk JSON parsing:** The initial awk implementation modified `$0` via `gsub`, which broke subsequent pattern matching when the whole JSON was on a single line. Using `_l = $0` copies preserves `$0` for all patterns. This pattern is now applied consistently across all 4 awk parsers (lookup, batch_list JSON, batch_list text, menu assembly).
- **Dynamic menu via temp file:** Instead of modifying menu.sh's internal data structures (risky — complex eval-based state), the plan generates a temp merged menu.db file. This is cleaner and doesn't touch the TUI rendering engine at all.
- **sed-based JSON merge for FLU_REGISTRIES:** Initial awk-based merge failed with pretty-printed multi-line JSON. Switched to simple sed bracket stripping + comma join which handles both compact and pretty-printed JSON correctly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed awk $0 mutation breaking single-line JSON parsing**
- **Found during:** task 3 (integration testing)
- **Issue:** awk `gsub` modifies `$0`, so subsequent pattern-action blocks on the same line see corrupted data. Pretty-printed JSON worked (one field per line) but compact single-line JSON failed silently.
- **Fix:** Changed all 4 awk parsers to use `_l = $0` line copies instead of modifying `$0` directly
- **Files modified:** modules.sh, flu.sh
- **Verification:** Tested with both compact `[{"a":"b"}]` and pretty-printed multi-line JSON — both work
- **Committed in:** 26da7b2 (task 3 commit)

**2. [Rule 1 - Bug] Fixed JSON bracket double-wrapping in registry merge**
- **Found during:** task 3 (integration testing)
- **Issue:** `flu_registry_fetch` wrapped official registry JSON with `printf '[%s]'` but official content already had brackets, producing `[[...]]`
- **Fix:** Strip outer brackets from official fetch result with `sed 's/^\[//;s/\]$//'` before storing in `_frf_merged`
- **Files modified:** modules.sh
- **Verification:** Empty registry `[]` → `[]`, single-entry `[{...}]` → `[{...}]`
- **Committed in:** 26da7b2 (task 3 commit)

**3. [Rule 1 - Bug] Replaced broken awk merge with sed-based approach for FLU_REGISTRIES**
- **Found during:** task 3 (integration testing)
- **Issue:** Multi-line awk merge logic failed to properly join JSON objects from different registries
- **Fix:** Simplified to sed bracket stripping + comma concatenation — handles both compact and pretty-printed JSON
- **Files modified:** modules.sh
- **Verification:** Two-registry merge test: both modules found via lookup after merge
- **Committed in:** 26da7b2 (task 3 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 — bugs discovered during testing)
**Impact on plan:** All fixes were correctness bugs that would have caused runtime failures. No scope creep.

## Issues Encountered

None beyond the deviations documented above — all edge case tests passed after fixes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Module registry fully functional with community module discovery, TUI integration, and SHA256 verification
- All ADVN-02 requirements satisfied
- Ready for remaining v2.0 milestone phases (color themes, progress bar, logging, etc.)
- PowerShell parity (flu.ps1) will need equivalent registry implementation

## Self-Check: PASSED

All files exist, all commits found in git log.

---
*Phase: 12-advanced-module-system*
*Completed: 2026-05-28*
