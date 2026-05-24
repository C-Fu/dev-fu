# Phase 5: Integration & Orchestrator - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire TUI, menus, and modules into `flu.sh` — a complete single-file orchestrator script deployable via curl-pipe-bash. Coexists with `fu.sh` on a dedicated `flu.sh` development branch. Handles TTY reattachment, platform detection, TUI initialization, menu-to-module dispatch, spinner display, and error recovery.

**Scope anchor:** Integration wiring only. All subsystems (tui.sh, menu.sh, modules.sh) are already built in Phases 1-4 and are unchanged. The orchestrator sources them, coordinates them, and provides the entry point.

**Requirements:** ENGN-09, INTG-01, INTG-02, INTG-05, GIT-01
</domain>

<decisions>
## Implementation Decisions

### flu.sh entry point & structure
- **D-01:** `flu.sh` sources subsystems at runtime (import pattern). Sources `tui.sh`, `menu.sh`, and `modules.sh` in order. Same pattern as `menu.sh` sourcing `tui.sh`.
- **D-02:** TTY reattachment (ENGN-09): detect stdin is a pipe, reopen `/dev/tty`, exec to reattach. If `/dev/tty` unavailable, fall back to non-TUI numbered prompt mode (same as `_tui_use_tui=false`). Matches the project's curl-pipe-bash identity.
- **D-03:** `flu.sh` sources platform detection from `modules.sh`'s `flu_module_set_env()` — reuses existing FLU_* env vars rather than duplicating detection code.

### End-to-end execution flow
- **D-04:** Main flow: TTY check/reattach → platform detection & env setup → TUI init → menu loop (`flu_menu_navigate("menu.db")`) → on leaf select: `flu_module_execute(action_id)` → return to menu. Clean state machine.
- **D-05:** Spinner (INTG-01): reusable component added to `tui.sh`. A rendering function that shows a rotating character over a box-rendered area. Called by `modules.sh` during fetch, available to any future subsystem.
- **D-06:** On successful module execution, result modal displays. User presses any key to return to the menu loop. On cancellation/error, return to menu loop or exit cleanly.

### Error handling & recovery hints
- **D-07:** Exit codes map to recovery messages at the orchestrator level. Each subsystem defines its own error codes. `flu.sh` maps them to user-facing messages with actionable hints. Subsystems don't display their own recovery hints — the orchestrator owns the user-facing error display.
- **D-08:** Terminal state is always restored on every exit path (normal exit, error, signal). `tui_restore()` in signal traps handles INT/TERM/HUP/QUIT across all subsystems.

### Branch strategy & coexistence
- **D-09:** Development on `flu.sh` branch per GIT-01. `fu.sh` continues to work unaffected on `main`. When `flu.sh` is stable and validated, merge to `main`.
- **D-10:** `flu.sh` and `fu.sh` coexist in the same repo at root level. Both are independent scripts — no code sharing, no conflicts. `flu.sh` does NOT source or depend on `fu.sh`.
- **D-11:** No separate `--demo` for flu.sh. Running `flu.sh` is the demo — it loads the real menu.db and executes the full pipeline.

### OpenCode's Discretion
- Exact spinner character sequence and rendering implementation
- Exit code values for each subsystem (use existing conventions)
- Exact TTY reattachment implementation (can reference fu.sh pattern)
- Signal handler registration order
- Startup platform status display format
- How to structure flu.sh file (sections, ordering)
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements
- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, requirements (ENGN-09, INTG-01, INTG-02, INTG-05, GIT-01)
- `.planning/REQUIREMENTS.md` — Detailed requirement descriptions

### Subsystem source files (must understand APIs)
- `tui.sh` (2130 lines) — TUI engine: `tui_init()`, `tui_restore()`, `_tui_read_key()`, all widgets, box rendering, color constants, spinner rendering
- `menu.sh` (780 lines) — Menu system: `flu_menu_navigate()`, `flu_menu_get_action()`, `flu_menu_get_children()`, `_flu_menu_render()`
- `modules.sh` (924 lines) — Module pipeline: `flu_module_fetch()`, `flu_module_parse_metadata()`, `flu_module_set_env()`, `flu_module_collect_params()`, `flu_module_execute()`, `flu_module_display_result()`
- `menu.db` (16 lines) — Menu definition file

### Prior context
- `.planning/phases/01-tui-engine-core/01-CONTEXT.md` — TUI decisions: `tui_` prefix, source+function API, /dev/tty reads, dual return pattern, signal traps
- `.planning/phases/02-interactive-widgets/02-CONTEXT.md` — Widget decisions: return value conventions (D-19-23), widget UX patterns
- `.planning/phases/04-module-architecture/04-CONTEXT.md` — Module decisions: D-09 pipeline, platform env vars (D-11), result display (D-12)

### Pattern reference
- `fu.sh` (2629 lines) — Reference for: TTY reattachment pattern (lines 41-47), `detect_platform()` / `detect_distro()` / `get_pkg_manager()` patterns (already adapted in modules.sh)
- `.planning/codebase/ARCHITECTURE.md` — fu.sh main loop pattern, entry points, error handling conventions

### Constraints
- `.planning/codebase/CONCERNS.md` — POSIX anti-patterns: no `$'\033'`, no `echo -e`, no `sed '\x1b'`
- `.planning/codebase/CONVENTIONS.md` — `snake_case`, `_flu_` internal prefix, `flu_` public functions
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tui.sh` (2130 lines): Complete TUI engine with all 5 widgets, box rendering, key reading, spinner. No changes needed — just sourced.
- `menu.sh` (780 lines): Full 3-level menu with breadcrumb navigation, fallback mode. No changes needed.
- `modules.sh` (924 lines): Complete module pipeline (fetch→parse→prompt→execute→display). No changes needed.
- `menu.db` (16 lines): 12-item menu definition. Already works.
- `fu.sh` (2629 lines): Reference patterns for TTY reattachment and platform detection. Not sourced — patterns adapted.
- `flu_module_set_env()` already exports all 7 FLU_* vars — orchestrator just calls it once at startup.

### Established Patterns
- `source` + function call API — all subsystems are library-first, demo-second
- `/dev/tty` explicit reads for keyboard input
- `tui_init()` / `tui_restore()` terminal lifecycle
- Signal traps in init function (INT/TERM/HUP/QUIT)
- Dual return: stdout + global + exit code
- ShellCheck pragmas for POSIX compliance

### Integration Points
- `flu_menu_navigate("menu.db")` returns action ID when user selects leaf — orchestrator passes to `flu_module_execute(action_id)`
- `flu.sh` is the entry point that calls `tui_init()`, then enters the menu loop
- TTY reattachment runs BEFORE `tui_init()` — ensures terminal is ready
- After module execution, control returns to the menu loop (not exit)
- All subsystems are source-only — no child processes, no IPC needed

### Patterns to Maintain
- POSIX sh compatibility: no bashisms
- Zero external dependencies beyond curl/wget
- `_flu_` prefix for internal variables, `flu_` for public
- Source + function call API
- `/dev/tty` explicit reads
- Signal-safe cleanup
</code_context>

<deferred>
## Deferred Ideas

- CLI batch mode (`flu.sh --install python --global`) — INTG-06 (v2)
- Color themes via FLU_THEME env var — INTG-07 (v2)
- Progress bar for known-length downloads — INTG-08 (v2)
- Module execution logging to file — INTG-10 (v2)
</deferred>

---

*Phase: 05-integration-&-orchestrator*
*Context gathered: 2026-05-25*
