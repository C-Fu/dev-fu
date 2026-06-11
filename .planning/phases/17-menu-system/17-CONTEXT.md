# Phase 17: Menu System - Context

**Gathered:** 2026-06-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the hierarchical menu DSL parser and 3-level navigation engine from menu.sh (897 lines POSIX shell) to Rust. Menu renders identically to flu.sh with colored borders, breadcrumbs, numbered items, and space-bar queue for batch execution. menu.db is already embedded at compile time (Phase 15). Module execution, registry, and integration are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Navigation model
- **D-01:** Hybrid navigation — tree structure for navigation state, flat list for data. Tree nodes reference indexes into the flat menu.db list. Combines intuitive navigation with simple data storage.

### Breadcrumb rendering
- **D-02:** Breadcrumbs in title bar — `"Developer Tools > Languages"` in the Block title with `> ` separator. Compact, always visible, matches menu.sh approach.

### Space-bar queue UX
- **D-03:** Highlight + separate panel — queued items highlighted with different color, small panel on right side shows queue contents. More visual than menu.sh's checkmark approach but provides clear feedback on what's queued.

### Action dispatch
- **D-04:** Return action_id — menu function returns `Vec<String>` of action_ids. Caller (main.rs) handles execution. Clean separation of concerns, matches menu.sh's stdout-based approach.

### Widget integration
- **D-05:** Use Phase 16's select widget as base — extend select widget with breadcrumb title, queue panel, and multi-select capability rather than building custom menu widget from scratch.

### Key handling
- **D-06:** Extend widget-local key handling — Space queues/unqueues item, Enter confirms selection(s), Esc goes back/up a level, q quits. Arrow keys, vim keys (j/k/g/G), go-to (digits), help toggle (?) inherited from Phase 16.

### Rendering
- **D-07:** Use ratatui Layout with horizontal split — main area for menu list (left ~75%), queue panel (right ~25%). Breadcrumbs in Block title. Footer shows help text and queue count.

### Data structure
- **D-08:** Extend existing MenuEntry from Phase 15 — add navigation metadata (parent/child relationships) but keep the core struct. Build navigation tree at startup from flat list.

### OpenCode's Discretion
- Exact tree node struct fields and navigation state management
- Queue panel layout (width, position, styling)
- Color scheme for queued items vs normal items
- Breadcrumb truncation for long paths
- Error handling for malformed menu.db entries
- Exact ratatui widgets used for queue panel (Block, List, Paragraph)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source being ported
- `menu.sh` — The complete POSIX menu system (897 lines). All navigation logic, breadcrumb formatting, queue handling, and rendering must be understood from this file.

### Project context
- `.planning/ROADMAP.md` §Phase 17 — Phase goal, success criteria, plan split (17-01)
- `.planning/phases/16-tui-engine/16-CONTEXT.md` — Phase 16 decisions (ratatui, widgets, key handling)
- `.planning/phases/15-rust-scaffold/15-CONTEXT.md` — Phase 15 decisions (binary name, menu.db embedding)

### Existing Rust codebase
- `fust/src/menu.rs` — Current menu.db parser (parse_menu_db, print_table, print_json). MenuEntry struct defined here.
- `fust/src/tui/widgets/select.rs` — Select widget from Phase 16. Menu will extend this with breadcrumbs and queue.
- `fust/src/tui/terminal.rs` — TerminalGuard from Phase 16. Menu uses this for terminal safety.
- `fust/src/tui/theme.rs` — Theme from Phase 16. Menu uses this for colors and box chars.
- `fust/src/tui/input.rs` — Key enum and read_key from Phase 16. Menu uses this for keyboard input.
- `menu.db` — 62-line pipe-delimited menu definition (Category|Subcategory|Label|action_id). Already embedded via include_str!.

No external specs — requirements fully captured in decisions above and ROADMAP.md success criteria.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `fust/src/menu.rs` — MenuEntry struct and parse_menu_db() function. Already parses embedded menu.db into sorted Vec<MenuEntry>.
- `fust/src/tui/widgets/select.rs` — Select widget with vim keys, go-to, help toggle, ratatui scrolling. Menu extends this.
- `fust/src/tui/terminal.rs` — TerminalGuard RAII. Menu uses this for terminal init/restore.
- `fust/src/tui/theme.rs` — Theme struct with dark defaults. Menu uses this for colors.
- `fust/src/tui/input.rs` — Key enum and read_key(). Menu uses this for keyboard input.

### Established Patterns
- anyhow for error handling
- include_str! for compile-time asset embedding (menu.db)
- Module-per-concern layout: menu.rs, tui/ module directory
- Tests are inline #[cfg(test)] mod tests in each module
- Widget-local key handling (Phase 16 pattern)

### Integration Points
- `menu.rs` — Extend MenuEntry with navigation metadata, add tree building function
- `main.rs` — Menu function returns Vec<String> of action_ids, main.rs handles execution
- `tui/widgets/select.rs` — Extend select widget with breadcrumb title and queue panel
- `Cargo.toml` — No new dependencies needed (ratatui + crossterm already added in Phase 16)

</code_context>

<specifics>
## Specific Ideas

- "Hybrid navigation" — tree for navigation state (current path, parent/child relationships), flat list for data (menu.db entries). Tree nodes store indexes into the flat list.
- "Highlight + separate panel" — queued items highlighted with theme.highlight color, right-side panel shows queue contents with numbers (1. action_id, 2. action_id).
- "Breadcrumbs in title" — use ratatui Block::title() with formatted string "Main Menu > Developer Tools > Languages". Bold white text on cyan background.

</specifics>

<deferred>
## Deferred Ideas

- Async spinner during module execution — belongs in Phase 18/20 when module pipeline is ported
- Search/filter within menu — future enhancement, not in Phase 17 scope
- Keyboard shortcuts for direct category jump (e.g., 'd' for Developer Tools) — future enhancement
- Configurable queue panel width — keep simple for now, can add later

</deferred>

---

*Phase: 17-menu-system*
*Context gathered: 2026-06-11*
