# Phase 4: Module Architecture - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Scripts fetch, validate, and execute remote module scripts from GitHub on demand — with platform context, inline parameter collection, and clear result reporting. This is the `flu_menu_get_action()` → execution pipeline: when the user selects a leaf menu item, the action identifier triggers a remote module fetch, parameter prompt, and execution.

**Scope anchor:** Module fetching, metadata parsing, parameter collection, execution, and result display. Does NOT include: the orchestrator that wires everything together (Phase 5), the PowerShell port (Phase 6), or module content authoring (sample modules only, real modules are external).

**Requirements:** MODL-01, MODL-02, MODL-03, MODL-04, MODL-05
</domain>

<decisions>
## Implementation Decisions

### Module script format & metadata
- **D-01:** Comment-block header format at the top of each module script. Fields use `@key: value` syntax, one per line, terminated by a blank line or first non-comment line. Parse with awk — same pattern as menu.db DSL parsing.
- **D-02:** Rich metadata fields required: `@name` (display name), `@params` (parameter declarations with type and choices), `@platforms` (comma-separated OS list), `@version` (module version string), `@deps` (comma-separated dependency action IDs), `@timeout` (max execution seconds).
- **D-03:** Parameter format: `@params: name=type:choice1,choice2;name=type:choice1,choice2`. Supported types: `radio` (single-select from choices), `text` (freeform input), `yesno` (boolean confirmation).
- **D-04:** Module scripts live in a single dedicated GitHub repo (`flu-modules`) under a known path convention. Base URL resolvable from the action identifier. Example: `install_python` → `https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/install_python.sh`.

### Fetch strategy & error handling
- **D-05:** Pipe-to-sh execution (curl-pipe-bash style). No temp file — download and pipe directly. Matches the project's curl-pipe-bash identity.
- **D-06:** Fetch fresh every time. No caching. Module content is always current.
- **D-07:** Retry 3 times with 2-second delay on network failure (fu.sh `retry_network()` pattern). Show a rotating spinner during fetch (INTG-01).
- **D-08:** On persistent failure: display the failed URL, HTTP status code, and actionable message ("Check internet connection", "Module not found — might be renamed", etc.).

### Parameter collection & execution flow
- **D-09:** Execution order: Fetch → parse metadata → prompt for params → pipe+execute → display results.
- **D-10:** Before execution, each `@param` triggers the appropriate Phase 2 widget: `radio` → `tui_radio_list()`, `text` → `tui_text_input()`, `yesno` → `tui_yesno()`. Parameter values are collected then passed to the module as command-line args via `sh -s -- --scope global --name foo`.
- **D-11:** Platform context passed via environment variables before execution. Reuse fu.sh's detection patterns: `FLU_OS` (linux/macos), `FLU_DISTRO` (ubuntu/alpine/arch), `FLU_PKG_MGR` (apt/apk/pacman/dnf/zypper/brew), `FLU_ARCH` (x86_64/aarch64), `FLU_IS_WSL`, `FLU_IS_TERMUX`, `FLU_IS_ROOT`.

### Module output display
- **D-12:** Results displayed in a box-rendered modal matching the TUI style. Clear screen, bordered box with module output inside, status banner at top (green ✓ success / red ✗ failure).
- **D-13:** Success: show last meaningful line of stdout. Failure (exit != 0): show stderr content + recovery hints derived from the exit code or error pattern.

### Module security & isolation
- **D-14:** Execute modules with `set -euo pipefail` enforced. Add a trap on EXIT to capture exit code. Modules run in a subshell.
- **D-15:** Configurable timeout per module (via `@timeout` metadata field). Default 300 seconds. Kill the subshell if exceeded.
- **D-16:** Modules run as the current user — they handle their own privilege escalation internally (same as fu.sh pattern with `_maybe_sudo()`).

### OpenCode's Discretion
- Exact `@param` syntax and parser implementation details
- `@deps` resolution order and cycle detection
- Spinner rendering implementation (reuse from tui.sh or write new)
- Exact recovery hint wording per error pattern
- Timeout mechanism (background process + kill, or other approach)
- Module metadata parser function name and internal variable naming
- How the action ID maps to the GitHub URL (config file, convention, or hardcoded)
</decisions>

<specifics>
## Specific Ideas

- The module system should feel like a natural extension of curl-pipe-bash — the same pattern users already know, now with prompts and context
- Module metadata parsing should feel like the menu.db DSL — `awk -F` patterns, same level of simplicity
- The result modal should look like a natural progression from the menu — you select something, you see results, you go back
</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 4 goal, success criteria, requirements mapping
- `.planning/REQUIREMENTS.md` — MODL-01 through MODL-05 (module architecture requirements), INTG-01 (spinner, in scope)
- `.planning/PROJECT.md` — POSIX compliance, zero-dependency, curl-pipe-bash ready identity, Key Decisions table

### Phase 1-3 foundation documents (patterns and APIs)
- `tui.sh` — TUI engine: `tui_init()`/`tui_restore()`, `_tui_read_key()`, `_tui_read_byte()`, box rendering primitives, widget functions (`tui_radio_list()`, `tui_text_input()`, `tui_yesno()`), color constants, spinner rendering
- `menu.sh` — Menu navigation: `flu_menu_navigate()`, `flu_menu_get_action()` returns action identifiers consumed by this phase
- `menu.db` — Menu DSL file: reference for pipe-delimited format pattern

### Prior context
- `.planning/phases/01-tui-engine-core/01-CONTEXT.md` — Phase 1 decisions: `tui_` prefix (D-04), source+function API (D-02), single file (D-01), `/dev/tty` explicit reads (D-07), dual return pattern (D-05)
- `.planning/phases/02-interactive-widgets/02-CONTEXT.md` — Phase 2 decisions: widget UX patterns, return value conventions (D-19-23), `[x]`/`[ ]` checkbox rendering
- `.planning/phases/03-menu-system/03-01-SUMMARY.md` — Phase 3 implementation: `flu_menu_get_action()` output format, menu tree query functions

### Pattern reference
- `fu.sh` (2629 lines) — Reference for: `detect_platform()`, `detect_distro()`, `detect_environment()`, `get_pkg_manager()`, `_maybe_sudo()`, `retry_network()`, `die()`, GitHub API fetching (`_scc_gh()`), color-coded error messages
- `.planning/codebase/ARCHITECTURE.md` — fu.sh platform abstraction layer (lines 160-321), error handling patterns
- `.planning/codebase/INTEGRATIONS.md` — GitHub raw URL patterns, curl usage, API auth patterns

### Constraints
- `.planning/codebase/CONCERNS.md` — POSIX anti-patterns to avoid: `$'\033'` (use `printf`), `echo -e` (use `printf`), `sed '\x1b'` (use `printf` substitution)
- `.planning/codebase/CONVENTIONS.md` — Naming conventions: `snake_case`, `_flu_` prefix for internal helpers, `flu_` for public functions
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fu.sh:detect_platform()` (line 191+) — OS detection: Linux/macOS/WSL2/Termux/Chromebook. Returns `DETECTED_OS`.
- `fu.sh:detect_distro()` (line 210+) — Distro detection via `/etc/os-release`. Returns `DETECTED_DISTRO`.
- `fu.sh:get_pkg_manager()` (line 235+) — Package manager detection: apt/apk/dnf/pacman/zypper/brew/winget/choco.
- `fu.sh:retry_network()` (line 139-155) — Retry wrapper: `retry_network 3 5 "curl ..."` — 3 attempts, 3s delay.
- `fu.sh:_maybe_sudo()` (line 244+) — Conditionally prefix commands with sudo.
- `fu.sh:die()` (line 131-134) — Fatal error with red message.
- `tui.sh:tui_init()` / `tui_restore()` — Terminal state management with signal traps.
- `tui.sh` widgets — `tui_radio_list()`, `tui_text_input()`, `tui_yesno()` for parameter prompts.
- `menu.sh:flu_menu_get_action()` — Returns action identifier for selected leaf menu item.
- `menu.sh:flu_menu_get_children()` / `flu_menu_is_leaf()` — Tree query functions.

### Established Patterns
- Pipe-delimited parsing with `awk -F'|'` (from menu.db DSL)
- `sed "s/'/'\\\\''/g"` sanitization on eval assignments (from tui.sh and menu.sh)
- Comment-based comment headers parsed as structured data (menu.db `#` comments)
- `_flu_` prefix for internal variables, `flu_` for public functions
- Dual return: stdout + TUI_RESULT global + exit code
- ShellCheck pragmas: `# shellcheck disable=SC2034,SC2154` for eval-assigned variables
- Zero bashisms enforced: no `[[ ]]`, `echo -e`, `$'\033'`, `${var:0:1}`, `let`, `local`

### Integration Points
- `flu_menu_navigate()` returns the action identifier when user selects a leaf — this phase receives that identifier
- Platform detection code can be extracted/adapted from fu.sh into a shared module
- Parameter prompt widgets (radio, text, yesno) are already available in tui.sh from Phase 2
- Result display can reuse `_flu_menu_render()` box rendering pattern from menu.sh
- Module scripts are external — they live in a separate GitHub repo, not in this repo

### Patterns to Maintain
- POSIX sh compatibility: no bashisms, every line passes `shellcheck -s sh`
- Zero external dependencies (curl/wget are the only network tools)
- `/dev/tty` explicit reads for keyboard input
- Signal-safe cleanup via `tui_restore()` in traps
- Source + function call API (scripts are libraries first, demos second)
</code_context>

<deferred>
## Deferred Ideas

- Module caching with TTL — MODL-07 (v2)
- SHA256 checksum verification — MODL-08 (v2)
- Module registry with auto-discovery — MODL-06 (v2)
- Module execution logging to file — INTG-10 (v2)
- CLI batch mode (`flu.sh --install python --global`) — INTG-06 (v2)
</deferred>

---

*Phase: 04-module-architecture*
*Context gathered: 2026-05-25*
