# Phase 10: Module Pipeline Hardening - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Hardens the module fetch/execute pipeline in modules.sh with SHA256 checksum verification, local caching with TTL, download progress indication, and execution logging. The pipeline currently fetches modules from GitHub raw URLs to /tmp with no verification, no caching, no progress, and no logging.

</domain>

<decisions>
## Implementation Decisions

### Checksum Verification
- **D-01:** Central MANIFEST.sha256 file in `modules/` directory — one file listing all module checksums
- **D-02:** Standard sha256sum output format (`<hash>  <filename>` per line) — verifiable with `sha256sum -c`
- **D-03:** Soft-fail on manifest unavailability — if MANIFEST.sha256 can't be fetched, proceed without checksum verification (log a warning)

### Module Caching
- **D-04:** Cache directory: `~/.cache/flu.sh/` (XDG cache standard)
- **D-05:** Cache key: action_id (e.g., `install_go`) — simple file-per-module
- **D-06:** Default TTL: 24 hours — configurable via `FLU_CACHE_TTL` env var (seconds)
- **D-07:** Cache invalidation: serve from cache if file exists and mtime < now - TTL; otherwise re-fetch

### Download Progress
- **D-08:** Simple `\r` overwrite showing percentage and bytes received: `Downloading install_go.sh... 45% (12K/26K)`
- **D-09:** Falls back to spinner if Content-Length header unavailable (no percentage)

### Execution Logging
- **D-10:** Log format: TSV (tab-separated values) — timestamp, action_id, operation (install/remove), result (success/fail), version, duration
- **D-11:** Log location: `~/.local/share/flu.sh/execution.log` (XDG data dir)
- **D-12:** Append-only, no rotation — logs are small (one line per execution)

### OpenCode's Discretion
- Exact curl flags for progress parsing
- Cache directory creation and permission handling
- Log file header/structure details
- How to handle cache corruption (re-fetch silently)
- How to integrate progress into existing `flu_module_fetch()` flow

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Module Pipeline (current implementation)
- `modules.sh` — Full module fetch/parse/execute pipeline (898 lines). Key functions: `flu_module_fetch()`, `flu_module_execute()`, `flu_module_resolve_url()`, `_flu_execute_with_timeout()`
- `flu.sh` — Main entry point, calls `flu_module_execute()` at line 335
- `modules/README.md` — Module contract, metadata header format, action ID registry

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — System overview, data flow, layer descriptions
- `.planning/codebase/CONCERNS.md` — Security considerations (piping unverified remote scripts), performance bottlenecks

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `flu_module_resolve_url()` (modules.sh:40-47): Builds GitHub raw URL from action_id — unchanged by this phase
- `flu_module_fetch()` (modules.sh:58-110): Current fetch logic writes to `/tmp/flu_module_$$.sh` — needs caching and checksum integration
- `flu_module_execute()` (modules.sh:593-660): Orchestrator calling fetch → parse → execute — needs logging integration
- `_flu_execute_with_timeout()` (modules.sh:553-575): Timeout wrapper for execution — needs duration logging

### Established Patterns
- Module scripts use `set -eu` and `_maybe_sudo()` helper pattern
- `FLU_PKG_MGR` env var set by `flu_module_set_env()` for platform dispatch
- `/tmp/flu_module_$$.sh` temp file pattern — cache replaces this for cached modules
- `FLU_*` env var naming convention for configuration

### Integration Points
- `flu_module_fetch()` — primary integration point for caching + checksums + progress
- `flu_module_execute()` — integration point for logging (after execution completes)
- `flu.sh:335` — single call site for `flu_module_execute()`
- `flu_module_resolve_url()` — produces URL used by fetch, may need manifest URL too

</code_context>

<specifics>
## Specific Ideas

- MANIFEST.sha256 is generated at commit time and lives in `modules/MANIFEST.sha256` in the repo
- Cache files should be named by action_id (e.g., `~/.cache/flu.sh/install_go`)
- Log TSV fields: `timestamp\taction_id\toperation\tresult\tversion\tduration_seconds`
- Progress display only during active download, not for cache hits

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 10-Module Pipeline Hardening*
*Context gathered: 2026-05-28*
