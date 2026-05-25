# Phase 7: Feature Parity - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Expand flu.sh to match all 18 fu.sh menu operations. Reorganize menu.db into functional category submenus with emoji-prefixed labels. Create POSIX sh module scripts with real install logic for each tool, referencing fu.sh patterns but writing fresh code.

**Scope anchor:** Menu expansion + module scripts. Intro polish (Phase 8) and documentation (Phase 9) are separate phases. No new features beyond what fu.sh already provides.

**Requirements:** MENU-05, MENU-06, MENU-07, MODL-06, MODL-07, MODL-08
</domain>

<decisions>
## Implementation Decisions

### Menu category structure
- **D-01:** Functional grouping into 6 categories with submenus:
  - **Diagnostics**: Status Check, Compare With Latest, Upgrade All Tools
  - **Languages & Runtimes**: Go, Rust, Python + Pip + UV + Pipx, NVM + Node LTS, Bun, PHP + Laravel
  - **Tools**: Yarn, Docker, Tailscale, OpenCode + GSD + OpenChamber
  - **Shell**: Fancy Prompt (Purple-Pink), Fancy Prompt (Shades of Blue), Hostname Discovery (Linux only)
  - **Settings**: GitHub Token, Mouse Reporting (Disable/Enable)
- **D-02:** Emoji-prefixed labels matching fu.sh style: 🔍 Status Check, 🔄 Compare With Latest, ⬆️ Upgrade All, etc.
- **D-03:** menu.db pipe-delimited format: `Category|Subcategory|Label|action_id`. Example: `Languages & Runtimes|Go|🐹 Install Go|install_go`.

### Module script strategy
- **D-04:** Write fresh POSIX sh module scripts following flu.sh conventions. Use fu.sh install functions as reference for commands, platform branching, and edge cases only — not copied directly.
- **D-05:** Each module script follows the flu.sh module conventions: `@key: value` comment header, `FLU_*` environment variables for platform context, standalone execution with `set -euo pipefail`.
- **D-06:** Modules handle platform-specific package manager commands (apt, apk, dnf, pacman, zypper, brew) using the detected `FLU_PKG_MGR` env var.

### Install/remove pairing
- **D-07:** Separate menu entries for install and remove operations. Each maps to a distinct action ID and module script. Example: `install_docker` and `remove_docker`.
- **D-08:** Install modules check for existing installation before proceeding (idempotent guard). Remove modules check for existing installation and confirm before removal.
- **D-09:** Tools without remove capability (Status Check, Compare, Upgrade All, Token) are display-only menu items or single-action.

### OpenCode's Discretion
- Exact module script naming convention and location within the flu-modules repo structure
- Specific POSIX sh implementation of each install/remove function (command sequences, error handling)
- How shell-specific modules (Fancy Prompts) adapt to POSIX sh from bash
- Edge case handling for Alpine (musl), macOS, WSL2 per tool
- Exact menu.db formatting and action ID naming
- Which tools require parameter prompts (e.g., global vs local scope) and which are zero-param
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 7 goal, success criteria, requirements
- `.planning/REQUIREMENTS.md` — v1.1 requirements, phase 7 mapping

### v1.0 implementation (patterns and APIs)
- `flu.sh` (285 lines) — Main entry point, TTY reattach, subsystem sourcing, main loop
- `menu.sh` (780 lines) — Menu navigation engine, DSL parser, breadcrumb display
- `menu.db` (16 lines) — Current 12-item menu definition. Reference format only — will be expanded.
- `modules.sh` (924 lines) — Module pipeline: fetch, metadata parse, execute, display. MODL-06 modules follow this pipeline.
- `tui.sh` (2261 lines) — TUI engine, widgets, rendering primitives

### fu.sh reference (install logic patterns)
- `fu.sh` (2629 lines) — Reference for: all 18 install/remove functions, platform detection, package manager abstraction, retry logic, error handling. Module scripts extract logic from here, not copy.
- `fu.sh:install_docker()` (lines 485-517) — Docker install pattern
- `fu.sh:install_go()` — Go install via package manager
- `fu.sh:install_rust()` — Rust via rustup
- `fu.sh:install_python()` — Python + pip + uv + pipx
- `fu.sh:install_nvm_node()` — NVM + Node LTS
- `fu.sh:install_bun()` — Bun via bun.sh/install
- `fu.sh:install_php_laravel()` — PHP + Composer + Laravel
- `fu.sh:create_fancy_prompt()` (lines 689-982) — Purple-Pink prompt template
- `fu.sh:install_avahi()` — Hostname Discovery (Linux only)
- `fu.sh:install_tailscale()` — Tailscale via official installer
- `fu.sh:set_github_token()` — GitHub token storage
- `fu.sh:status_check()` — Tool version checking
- `fu.sh:status_check_compare()` — Online version comparison
- `fu.sh:upgrade_all()` — Batch upgrade
- `fu.sh:pkg_install()/pkg_remove()/pkg_purge()` — Package manager abstractions

### Prior context
- `.planning/phases/04-module-architecture/04-CONTEXT.md` — Module pipeline decisions, @key metadata format, D-09 flow
- `.planning/phases/03-menu-system/03-01-SUMMARY.md` — Menu DSL format (pipe-delimited, awk -F'|')
- `.planning/PROJECT.md` — v1.1 milestone goals, constraints

### Constraints
- `.planning/codebase/CONCERNS.md` — POSIX anti-patterns to avoid
- `.planning/codebase/ARCHITECTURE.md` — fu.sh architecture, layers, patterns
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `modules.sh` (924 lines): Full module pipeline — all MODL-06 scripts use this for fetch/parse/execute/display. Nothing to change.
- `menu.sh` (780 lines): Menu system — handles all navigation. menu.db is the only file that changes.
- `tui.sh` (2261 lines): TUI engine — emoji support already via Unicode rendering. No changes needed.
- `flu.sh` (285 lines): Entry point — no changes needed. Sources subsystems, runs main loop.
- `menu.db` (16 lines): Current 12-item definition. Will be expanded to ~70 lines with 18 items + remove variants.

### Established Patterns
- Pipe-delimited DSL: `Level1|Level2|Level3|action` — new items follow same format
- Module metadata: `@key: value` comment headers — all new modules follow this
- FLU_* env vars: `fl_module_set_env()` already exports all 7 vars — modules use them directly
- Dual return pattern: stdout + TUI_RESULT + exit code — unchanged
- Subshell execution: `pipefail` + timeout + temp file capture — unchanged

### Integration Points
- menu.db is the ONLY file modified for menu structure. No code changes needed in menu.sh or flu.sh.
- Module scripts are EXTERNAL — they live in the flu-modules GitHub repo, not this repo
- Sample module scripts for testing can be placed locally, but production modules are remote
- flu.sh already calls `flu_module_execute(action_id)` — new action IDs just work

### What stays unchanged
- tui.sh — no changes (emoji already supported)
- menu.sh — no changes (menu.db handles all content)
- modules.sh — no changes (pipeline handles any module)
- flu.sh — no changes (main loop unchanged)
</code_context>

<deferred>
## Deferred Ideas

- Remove operations for all tools — in scope for this phase per D-07/D-08
- Module caching with TTL — v2
- SHA256 checksum verification — v2
</deferred>

---

*Phase: 07-feature-parity*
*Context gathered: 2026-05-25*
