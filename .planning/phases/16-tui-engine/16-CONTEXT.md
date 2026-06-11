# Phase 16: TUI Engine - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the entire tui.sh rendering engine (2262 lines POSIX shell) to Rust — terminal control, box drawing, keyboard input, and all 5 interactive widgets (select, checklist, radio, text input, yes/no). Menu system, module pipeline, and integration are separate phases.

</domain>

<decisions>
## Implementation Decisions

### TUI framework
- **D-01:** Use ratatui (built on crossterm) for TUI rendering, not raw crossterm alone
- **D-02:** Crossterm backend for ratatui (standard, well-supported)
- **D-03:** Use ratatui's built-in widgets (Block, List, Paragraph, Clear) as building blocks rather than fully custom rendering

### Rendering
- **D-04:** Double-buffer rendering (ratatui default) — draw to Buffer, flush diff to terminal. Flicker-free.
- **D-05:** Auto-adapt on terminal resize — widgets reflow to new dimensions automatically via ratatui's resize handling

### Widget architecture
- **D-06:** Struct per widget — `SelectState`, `ChecklistState`, `RadioState`, `YesNoState`, `TextInputState`. Each holds its own cursor, scroll, items, selection.
- **D-07:** Widget-local key handling — each widget implements its own `handle_event(KeyEvent)` method. Select maps j/k to up/down, checklist maps space to toggle, etc.
- **D-08:** Function API for widget callers — `fn select(title: &str, subtitle: &str, items: &[&str]) -> Result<Option<usize>>`. Simple, direct, similar to tui.sh's calling convention.

### Keyboard features
- **D-09:** Port number-key jump (go-to) — type digits to jump to item N, multi-digit support for large menus
- **D-10:** Port help toggle — `?` key toggles between compact and extended footer

### Scroll behavior
- **D-11:** Use ratatui's default ListState scrolling rather than matching tui.sh's exact scroll logic. Slightly different feel but less custom code.

### Locale / encoding
- **D-12:** Port locale detection from tui.sh — check `$LANG`/`$LC_ALL`/`$LC_CTYPE` at startup for UTF-8 support. Fall back to ASCII box chars (`+-|`) and radio glyphs (`(*)`) on non-UTF-8 terminals.

### Color / theming
- **D-13:** Theme abstraction — define a theme struct with configurable colors. Default theme matches tui.sh's dark-terminal colors. Supports future FLU_THEME feature.

### Terminal safety
- **D-14:** RAII guard + panic hook — `TerminalGuard` struct with `Drop` impl for terminal restore, `std::panic::set_hook` for panic recovery, `ctrlc` crate or `signal_hook` for signal handling. Guarantees terminal restore on all exit paths.

### Non-TTY behavior
- **D-15:** Skip non-TTY fallback prompts — fust requires a real terminal. Print error and exit if no TTY detected.

### Demo / testing
- **D-16:** Port demo flags — `fust --demo-select`, `--demo-checklist`, `--demo-radio`, `--demo-yesno`, `--demo-text-input` for standalone widget testing

### OpenCode's Discretion
- Exact ratatui version and feature flags
- Module file layout within `fust/src/tui/`
- Widget trait details and internal struct fields
- Error handling strategy within widgets (anyhow vs thiserror)
- Exact theme struct fields and color values
- Demo flag CLI integration with existing clap parser

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source being ported
- `tui.sh` — The complete POSIX TUI engine (2262 lines). All widget behavior, key mappings, rendering logic, and locale detection must be understood from this file.

### Project context
- `.planning/ROADMAP.md` §Phase 16 — Phase goal, success criteria, plan split (16-01, 16-02)
- `.planning/phases/15-rust-scaffold/15-CONTEXT.md` — Phase 15 decisions (binary name, project layout, dependencies)

### Existing Rust codebase
- `fust/Cargo.toml` — Current dependencies (clap 4, serde, serde_json, anyhow). ratatui + crossterm to be added.
- `fust/src/main.rs` — Entry point, currently prints "TUI mode not yet implemented (coming in Phase 16)"
- `fust/src/cli.rs` — Clap CLI parser. Demo flags to be added here.
- `fust/src/platform.rs` — Platform detection. TUI module integrates with this for locale detection.

No external specs — requirements fully captured in decisions above and ROADMAP.md success criteria.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fust/src/cli.rs` — Clap derive parser. Demo flags (`--demo-select`, etc.) extend this struct.
- `fust/src/platform.rs` — Platform detection. Locale detection for UTF-8 can extend this or be a separate module.
- `fust/src/main.rs` — Entry point. The "TUI mode not yet implemented" branch at line 29-33 is where the TUI launch goes.

### Established Patterns
- anyhow for error handling (`anyhow::Result<()>` in main)
- `include_str!("../../menu.db")` for compile-time asset embedding
- Module-per-concern layout: `cli.rs`, `menu.rs`, `platform.rs` → TUI code goes in `tui/` module directory
- Tests are inline `#[cfg(test)] mod tests` in each module

### Integration Points
- `main.rs:29-33` — "No args → TUI mode" branch needs to call TUI engine
- `cli.rs` — Demo flags extend the Cli struct with new `#[arg(long)]` fields
- `Cargo.toml` — Add `ratatui`, `crossterm` (and optionally `ctrlc` or `signal_hook`) dependencies

</code_context>

<specifics>
## Specific Ideas

- "Use ratatui's built-in widgets" — leverage Block for bordered boxes, List for scrollable items, Paragraph for text. Don't reinvent what ratatui provides.
- "Theme abstraction" — design for future FLU_THEME support even though theming is not in this phase's scope.

</specifics>

<deferred>
## Deferred Ideas

- Async spinner widget — belongs in Phase 18/20 when module execution needs progress feedback
- Non-TTY fallback prompts — skipped; fust requires a real terminal
- Exact scroll behavior match with tui.sh — using ratatui defaults instead

</deferred>

---

*Phase: 16-tui-engine*
*Context gathered: 2026-06-11*
