# Phase 11: Modern CLI Tools - Context

**Gathered:** 2026-05-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Create 8 POSIX sh module scripts (4 install + 4 remove) for modern CLI tools: lazygit, starship, zoxide, and eza. Add corresponding menu.db entries under a new "Modern CLI" submenu. Follow the exact same module contract and patterns established in Phase 7.

</domain>

<decisions>
## Implementation Decisions

### All Decisions — OpenCode Discretion
- **D-01:** User delegated all implementation decisions to OpenCode
- All 4 tools use the standard module contract from Phase 7 (set -eu, _maybe_sudo, FLU_PKG_MGR fallback)
- Install methods per tool (OpenCode selects best approach):
  - **lazygit**: curl-pipe from GitHub releases (pre-built Go binary)
  - **starship**: curl-pipe from official starship.rs install script (pre-built Rust binary)
  - **zoxide**: curl-pipe from GitHub releases (pre-built Rust binary)
  - **eza**: package manager where available, cargo install as fallback
- **starship vs fancy prompts**: Coexist — starship install does not touch existing fancy prompt configs. User can switch manually.
- All scripts support linux + darwin platforms
- All scripts have idempotent install guards (command -v check)
- Remove scripts clean up the installed binary and any shell integration lines

### Carried Forward from Phase 7
- Module metadata header format (unchanged)
- `_maybe_sudo()` helper (unchanged)
- `@timeout: 600` for curl-pipe installs, `@timeout: 300` for package manager installs
- Remove scripts use `rm -f` for binaries, `sed` to clean shell RC files

### Carried Forward from Phase 10
- All modules benefit from caching, checksums, progress, and logging automatically
- MANIFEST.sha256 will need updating after new modules are created

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Module Contract
- `modules/README.md` — Action ID registry, metadata header format, runtime contract
- `modules/install_go.sh` — Package manager install pattern (70 lines)
- `modules/remove_go.sh` — Package manager remove pattern (62 lines)
- `modules/install_rust.sh` — Curl-pipe install pattern (54 lines)
- `modules/install_tailscale.sh` — Curl-pipe install pattern (64 lines)
- `modules/remove_rust.sh` — Curl-pipe remove pattern

### Menu System
- `menu.db` — Current menu structure, new entries go under Languages & Runtimes or a new Modern CLI category

### Pipeline (from Phase 10)
- `modules.sh` — Fetch/cache/checksum/progress/logging pipeline
- `modules/MANIFEST.sha256` — Must be regenerated after adding new modules

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Module script template: shebang → metadata header → set -eu → _maybe_sudo() → FLU_PKG_MGR fallback → idempotent guard → install/remove logic
- `_maybe_sudo()` helper — copy-pasted into every module script (22 lines)
- FLU_PKG_MGR dispatch pattern — case switch for apt/apk/dnf/pacman/zypper/brew
- `menu.db` DSL — pipe-delimited: Category|Subcategory|Label|action_id

### Established Patterns
- Curl-pipe installs use `@timeout: 600` and `@deps: curl,wget`
- Package manager installs use `@timeout: 300` and `@deps:` (empty)
- Remove scripts reverse the install: remove binary, clean RC file lines
- All scripts are standalone (no sourcing of other project files)

### Integration Points
- `menu.db` — add new entries for each tool (install + remove)
- `modules/MANIFEST.sha256` — regenerate after adding new .sh files
- Pipeline (modules.sh) — no changes needed, new modules work automatically

</code_context>

<specifics>
## Specific Ideas

- New menu.db category or subcategory needed — "Modern CLI" under Languages & Runtimes, or a new top-level category
- starship needs shell integration (init command in RC file) — handle in install script
- zoxide needs shell integration (eval in RC file) — handle in install script
- Remove scripts for starship/zoxide must clean RC file integration lines
- lazygit is standalone binary, no shell integration needed
- eza may need aliases (ls → eza) — skip for now, document as user choice

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 11-Modern CLI Tools*
*Context gathered: 2026-05-28*
