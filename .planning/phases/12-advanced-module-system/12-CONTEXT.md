# Phase 12: Advanced Module System - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Add CLI batch mode for non-interactive execution and a module registry with auto-discovery for community-contributed modules. CLI batch mode lets users run `flu.sh --install go,rust,starship --yes` without entering the TUI. The module registry allows users to browse, discover, and install community-contributed module scripts alongside the official 55 modules.

**Requirements:** ADVN-01, ADVN-02
**Success Criteria:**
1. User can run `flu.sh --install go,rust,starship --yes` and have all three tools installed without entering the TUI
2. User can run `flu.sh --list` to see all available modules including community-contributed ones from the registry
3. User can discover and install a community-contributed module not bundled with flu.sh by default

</domain>

<decisions>
## Implementation Decisions

### CLI Flag Design
- **D-01:** Action flags pattern — `flu.sh --install <ids> --remove <ids> --yes`. Not positional subcommands. Multiple action flags compose naturally.
- **D-02:** Users pass exact action_ids (e.g., `install_go`, `remove_rust`) — no short-name mapping. Unambiguous, matches menu.db exactly.
- **D-03:** `--list` shows full module listing: category, name, action_id, installed status. Table format. Supports `--list --json` for machine-readable output.
- **D-04:** Minimal flag set for this phase: `--install`, `--remove`, `--list`, `--yes`. No `--status`, `--compare`, `--version` flags (future additions).

### Batch Execution Behavior
- **D-05:** Continue on failure — run all requested modules, collect results, print summary. One failure does not stop subsequent modules.
- **D-06:** Modules with `@params` are rejected in batch mode with clear error message: "Module X requires parameters — use interactive mode."
- **D-07:** Plain text status lines — no JSON, no TUI widgets. Lines like `✓ install_go — Complete` / `✗ install_rust — Failed (exit 1)`. Final summary shows totals.
- **D-08:** Exit code: 0 if all modules succeed, 1 if any module fails. Standard CI-friendly behavior.
- **D-09:** ANSI colors stripped when stdout is not a TTY (batch mode detection via `[ -t 1 ]`).

### Registry Architecture
- **D-10:** GitHub-hosted JSON index file — a `registry.json` in a separate GitHub repo (e.g., flu.sh-registry). Each entry has: action_id, name, description, category, platforms, base_url, sha256. Fetched at runtime, no server needed.
- **D-11:** Users add third-party registries via `FLU_REGISTRIES` env var (space-separated URLs). Multiple registries merge — official first, then extras in order.
- **D-12:** Same SHA256 checksum model for community modules as official modules. Registry index includes expected hashes for each module script. No execution without verification.

### Registry Discovery UX
- **D-13:** Community modules appear in a new "Community Modules" top-level menu category in the TUI. Subcategory per registry or flat list.
- **D-14:** Namespace prefix prevents conflicts — community modules use `community/<action_id>` format (e.g., `community/install_neovim`). No shadowing of official modules.
- **D-15:** Same `--install` command works for community modules — `flu.sh --install community/install_neovim`. Registry index provides the base URL, same fetch/verify pipeline handles it.

### OpenCode's Discretion
- Exact CLI argument parsing implementation (getopts vs manual while/case)
- JSON parsing approach for registry index (awk/jq or simple grep/sed)
- How registry entries are cached and refreshed
- Menu.db generation for community modules (dynamic injection vs static append)
- How `--list --json` output is structured
- Error message wording and formatting details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Module Pipeline (current implementation)
- `modules.sh` — Full module fetch/parse/execute pipeline (1023 lines). Key functions: `flu_module_fetch()`, `flu_module_execute()`, `flu_module_resolve_url()`, `flu_module_parse_metadata()`, `flu_module_set_env()`
- `flu.sh` — Main entry point (357 lines). Currently no CLI arg parsing — always enters TUI loop. CLI args must be added before the main loop at line 300.
- `modules/README.md` — Module contract, metadata header format, action ID registry (55 modules)
- `modules/MANIFEST.sha256` — SHA256 checksum manifest format (reference for registry checksum model)

### Menu System
- `menu.sh` — Menu navigation engine (897 lines). Key functions: `flu_menu_navigate()`, `flu_menu_load()`, `flu_menu_get_action()`
- `menu.db` — Current 55-entry menu definition. Community modules add a new category dynamically.

### Architecture & Patterns
- `.planning/codebase/ARCHITECTURE.md` — System overview, data flow, layer descriptions
- `.planning/codebase/CONCERNS.md` — Security considerations

### Prior Context
- `.planning/phases/10-module-pipeline-hardening/10-CONTEXT.md` — Cache, checksum, progress, logging decisions that this phase builds on
- `.planning/phases/11-modern-cli-tools/11-CONTEXT.md` — Module contract patterns carried forward

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `flu_module_execute()` (modules.sh:706-803): 7-step pipeline — fetch, parse metadata, set env, platform check, param collection, execute with timeout, display result. Batch mode needs a variant that skips Step 5 (param collection) and Step 7 (keypress wait).
- `flu_module_fetch()` (modules.sh:84-182): Fetch with local check, cache check, remote fetch, SHA256 verify, cache store. Registry modules use this pipeline with a different base URL from the registry index.
- `flu_module_resolve_url()` (modules.sh:45-51): Builds GitHub raw URL from action_id. Registry modules need URL resolution from registry index instead.
- `_flu_fetch_manifest()` (modules.sh:61-72): Fetches MANIFEST.sha256. Same pattern for fetching registry.json.
- `_flu_log_execution()` (modules.sh): Already logs tool/action/result/timestamp. Batch mode results are logged here too.
- `flu_module_set_env()` (modules.sh): Exports FLU_OS, FLU_DISTRO, FLU_PKG_MGR, FLU_ARCH, FLU_IS_WSL, FLU_IS_TERMUX, FLU_IS_ROOT — batch mode needs these too.

### Established Patterns
- `FLU_*` env var naming convention for configuration
- `FLU_MODULES_BASE_URL` env var overrides module base URL — registry pattern extends this
- `FLU_CACHE_DIR` and `FLU_CACHE_TTL` for caching — registry index should be cached here too
- Module metadata `@key: value` comment headers — registry JSON mirrors these fields
- pipe-delimited menu.db DSL: `Category|Subcategory|Label|action_id` — community modules inject entries

### Integration Points
- `flu.sh:296-349` — Main event loop. CLI batch mode needs to intercept before this loop (before line 298) when CLI flags are present.
- `flu_menu_navigate()` — Interactive menu entry. CLI mode skips this entirely.
- `menu.db` — Static file. Community modules need dynamic menu generation (load registry, build temporary menu entries).
- `flu_module_execute()` — Primary execution function. Batch mode either reuses this (skipping interactive parts) or has a streamlined variant.

</code_context>

<specifics>
## Specific Ideas

- `flu.sh --install install_go,install_rust,install_starship --yes` is the canonical batch mode example
- `flu.sh --list` shows a table with columns: Category, Name, Action ID, Installed (yes/no)
- `flu.sh --list --json` for CI/CD scriptability
- Community module example: `flu.sh --install community/install_neovim`
- `FLU_REGISTRIES="https://raw.githubusercontent.com/user/repo/main/registry.json"` to add third-party sources
- Registry JSON structure: array of objects with `{action_id, name, description, category, platforms, base_url, sha256}`
- Batch mode summary: "3 succeeded, 1 failed" with individual results listed
- Modules with `@params` rejected in --yes mode with message pointing to interactive mode
- "Community Modules" appears as a new top-level menu category in TUI, populated from registry at startup

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-advanced-module-system*
*Context gathered: 2026-05-28*
