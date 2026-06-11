# Phase 17: Menu System - Discussion Log

**Date:** 2026-06-11
**Mode:** Standard discuss

## Areas Discussed

### 1. Navigation Model
**Options presented:**
- Tree structure — build tree at startup, navigate by entering/exiting nodes
- Flat list with path filtering — keep flat list, filter by path (matches menu.sh)
- Hybrid — tree for navigation state, flat list for data

**User selected:** Hybrid
**Notes:** Combines intuitive navigation with simple data storage. Tree nodes reference indexes into flat menu.db list.

### 2. Breadcrumb Rendering
**Options presented:**
- Title bar — in Block title: "Developer Tools > Languages" (matches menu.sh)
- Top line — separate line above menu, takes vertical space
- Status line — bottom of screen, below footer

**User selected:** Title bar
**Notes:** Compact, always visible, matches menu.sh approach. Uses ratatui Block::title().

### 3. Space-bar Queue UX
**Options presented:**
- Checkmarks + counter — [x] prefix, footer shows "3 queued" (matches menu.sh)
- Highlight + separate panel — highlighted items, right panel shows queue
- Numbered queue — 1., 2., 3. prefix, shows execution order

**User selected:** Highlight + separate panel
**Notes:** More visual than menu.sh but provides clear feedback. Right panel shows queue contents with numbers.

### 4. Action Dispatch
**Options presented:**
- Return action_id — menu returns Vec<String>, caller handles execution (matches menu.sh)
- Callback function — menu takes Fn(&str) -> Result<()>, inline execution
- Event emission — menu emits events, event loop handles execution

**User selected:** Return action_id
**Notes:** Clean separation of concerns. Menu focuses on navigation, caller (main.rs) handles module execution.

## Deferred Ideas
- Async spinner during module execution (Phase 18/20)
- Search/filter within menu (future enhancement)
- Keyboard shortcuts for direct category jump (future enhancement)
- Configurable queue panel width (keep simple for now)

## OpenCode's Discretion Items
- Exact tree node struct fields and navigation state management
- Queue panel layout (width, position, styling)
- Color scheme for queued items vs normal items
- Breadcrumb truncation for long paths
- Error handling for malformed menu.db entries
- Exact ratatui widgets used for queue panel

---

*Phase: 17-menu-system*
*Discussion completed: 2026-06-11*
