---
phase: 03-menu-system
plan: 01
status: complete
completed_at: 2026-05-24
tasks_completed: 2
files_created:
  - menu.sh
  - menu.db
shellcheck: PASS
sh-syntax: PASS
bashisms: 0
---

## Summary

Implemented the pipe-delimited menu DSL parser and tree query functions for the flu.sh menu system.

### What was built

- **menu.db** (16 lines): Sample menu definition file with 12 pipe-delimited entries covering all 3 levels (Developer Tools/Languages/Python, System/Monitoring/htop, Media/FFmpeg/Install, etc.). Format: `Level1|Level2|Level3|action`.

- **menu.sh** (289 lines): POSIX shell library with 5 public functions:
  - `flu_menu_load()` — Parses DSL file into indexed arrays (`_fm_line_N`, `_fm_l1_N`, `_fm_l2_N`, `_fm_l3_N`)
  - `flu_menu_get_children()` — Returns children of any path via stdout + indexed arrays
  - `flu_menu_is_leaf()` — Returns 0/1 exit codes for leaf checks
  - `flu_menu_get_breadcrumb()` — Converts pipe paths to "Main Menu > A > B" strings
  - `flu_menu_get_action()` — Extracts action field for full L1|L2|L3 paths

### Verification results

- **shellcheck -s sh**: PASS (zero errors/warnings)
- **sh -n syntax**: PASS
- **Bashisms audit**: 0 (no `[[ ]]`, `echo -e`, `$'\033'`, `${var:0:1}`, `let`, `local`)
- **Integration test**: PASS
  - 12 items loaded, 3 L1 items, 3 L2 items under "Developer Tools"
  - Breadcrumb "Main Menu > Developer Tools > Languages"
  - Action "install_python" for "Developer Tools|Languages|Python"
  - Leaf checks: Developer Tools=no, Dev Tools|Languages|Python=yes

### Key patterns established

- All parsing uses `awk -F'|'` — zero external dependencies beyond POSIX awk
- All `eval` assignments use `sed "s/'/'\\\\''/g"` sanitization (tui.sh pattern)
- All internal variables use `_fm_*` prefix, unset on function exit
- File-level `# shellcheck disable=SC2034,SC2154` directives

### Deviations

None.
