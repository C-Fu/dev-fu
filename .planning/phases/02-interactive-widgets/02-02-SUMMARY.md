---
phase: 02-interactive-widgets
plan: 02
type: execute
subsystem: TUI Engine
tags: [tui, radio, yesno, widgets, confirmation]
requires: [02-01]
provides: [tui_radio, tui_yesno, _tui_render_radio, _tui_render_yesno, _tui_radio_glyph_on, _tui_radio_glyph_off]
affects: [tui.sh]
tech-stack:
  added: []
  patterns: [eval-based-indexed-storage, full-screen-box-rendering, event-loop-with-key-dispatch, dual-return-stdout-TUI_RESULT, fallback-numbered-prompt, centered-modal-dialog, glyph-auto-detection]
key-files:
  created: []
  modified: [tui.sh]
key_decisions:
  - "Radio glyphs auto-detect UTF-8 vs ASCII using same locale heuristic as box-drawing chars"
  - "Radio: SPACE selects, ENTER confirms, Esc cancels — cursor and selection are independent"
  - "Radio default index pre-selects via --default N (0-based) with (•) indicator on open"
  - "Yes/No: centered modal dialog with Left/Right arrow navigation between Yes and No buttons"
  - "Yes/No: 'No' pre-selected by default for safety-first destructive operations"
  - "Yes/No: returns literal 'yes'/'no' strings consistent with D-22 convention"
duration: ~4 min
completed: 2026-05-24T06:23:10Z
---

# Phase 2 Plan 2: Radio & Yes/No Widgets — Summary

**One-liner:** Implements `tui_radio()` single-select radio button widget with Unicode `(•)`/`(○)` dot indicators (ASCII fallback) and `--default` pre-selection, plus `tui_yesno()` safety-first confirmation dialog with centered modal, Left/Right button navigation, and "No" pre-selected default.

---

## Tasks Completed

### Task 1: Implement `tui_radio()` single-select radio button widget

**Commit:** `2aaa294`

Built the complete radio button widget in four components:

- **`_tui_radio_init_glyphs()`** (Section 13) — Auto-detects UTF-8 locale and sets `_tui_radio_glyph_on='(•)'` / `_tui_radio_glyph_off='(○)'` for UTF-8, or `'(*)'` / `'( )`' for ASCII fallback. Uses the same heuristic as box-drawing character detection.

- **`_tui_radio_fallback()`** (Section 13a) — Numbered prompt for non-TTY environments. Lists items with `(•)`/`(*)` indicator for the selected item and `(○)`/`( )` for others. Accepts 1-based input numbers, returns 0-based index.

- **`_tui_render_radio()`** (Section 13b) — Full-screen rendering helper mirroring `_tui_render_select()` and `_tui_render_checklist()` exactly, with radio prefix (`(•)`/`(○)`), reverse-video cursor highlight, `↑more`/`↓more` scroll indicators, and status line showing "Selected: [label]" when an option is selected or "Item N of M" when navigating.

- **`tui_radio()`** (Section 13c) — Main widget with `--default N` parameter parsing, complete event loop dispatching on: `SPACE` (select current item), `ENTER` (confirm with zero-selection guard showing "Select an option"), `UP`/`DOWN`/`PGUP`/`PGDN`/`HOME`/`END` (navigation), `ESC`/`q` (cancel), `?` (toggle help footer). All `_tr_*` globals unset on every exit path. Demo mode via `sh tui.sh --demo-radio`.

### Task 2: Implement `tui_yesno()` confirmation dialog widget

**Commit:** `c9d8033`

Built the yesno confirmation dialog in three components:

- **`_tui_yesno_fallback()`** (Section 14) — Text-based prompt for non-TTY environments. Shows `[x] Yes` / `[ ] No` markers with the pre-selected default, accepts y/n/Enter input, returns literal `'yes'`/`'no'` string.

- **`_tui_render_yesno()`** (Section 14a) — Centered modal dialog rendering. Uses `_tui_draw_box()` for the frame (50×8 default dimensions, adjusted for small terminals), then overlays the message (centered), Yes/No buttons (reverse-video highlight on selected), and footer (`←→ Move  Enter=Confirm  Esc=Cancel`).

- **`tui_yesno()`** (Section 14b) — Main widget with "No" pre-selected by default. Event loop dispatches: `LEFT`/`RIGHT` (toggle between yes/no), `ENTER` (confirm — returns literal `'yes'`/`'no'` string to stdout and TUI_RESULT), `ESC` (cancel — exit 1), `?` (toggle help footer). All `_ty_*` variables unset on every exit path. Demo mode via `sh tui.sh --demo-yesno`.

---

## Deviations from Plan

None. Both widgets were implemented exactly as specified in the PLAN.md, following the established widget patterns from `tui_select()` (Phase 1) and `tui_checklist()` (Plan 02-01).

### Implementation Notes

- **Radio status line enhancement:** When an item is selected (via SPACE) but not yet confirmed, the status line displays "Selected: [label]" rather than just "Item N of M", providing clear visual feedback that a selection is pending confirmation. This is within OpenCode's discretion for status line text.
- **Radio fallback default handling:** The fallback prompt shows all items with `(•)`/`(○)` indicators but does not auto-submit the default. User must enter a number or cancel with empty input. This is consistent with how all widgets' fallback modes work — they list items and prompt for input.

---

## Key Implementation Details

### Radio Widget Rendering (D-09, D-10, D-11)

- **Glyph detection:** Auto-detects UTF-8 locale using `${LANG:-}${LC_ALL:-}${LC_CTYPE:-}` heuristic, same as `_tui_detect_box_chars()`. Sets `_tui_radio_glyph_on`/`_tui_radio_glyph_off` at module load time.
- **Independent cursor and selection:** `_tr_cursor` (navigation) and `_tr_selected` (confirmed via SPACE) are separate variables. User moves cursor with Up/Down, presses SPACE to select, ENTER to confirm. This means a user can navigate away from a selected item without losing the selection.
- **Zero-selection guard:** ENTER with no item selected shows "Select an option" in red on the status line, keeps the widget open. User must SPACE-select before confirming.
- **Pre-selected default:** `--default N` (0-based) sets `_tr_cursor` and `_tr_selected` to the Nth+1 item. Clamped to valid range if out of bounds.

### Yes/No Widget UX (D-12, D-13, D-14)

- **Centered modal:** Box position calculated as `(cols - box_w) / 2` and `(rows - box_h) / 2`. Minimum x/y of 1 to avoid off-screen rendering.
- **Button rendering:** Only the highlighted button gets reverse-video (`TUI_REV`). Both buttons occupy equal width (11 chars: `    Yes    `, `    No     `) centered within the box inner width.
- **Safety-first default:** "No" is pre-selected unless explicitly overridden via the third `default` argument. This protects against accidental destructive operations.
- **Footer placement:** The footer is rendered on the bottom border row of the dialog box (`_ty_y + _ty_box_h - 1`), replacing the corner character with dimmed keyboard hint text. This keeps the dialog compact and self-contained.

### Return Value Conventions (D-19, D-22, D-23)

- **Radio (success, exit 0):** Prints the 0-based index to stdout as a single line. Sets `TUI_RESULT` to the same 0-based integer.
- **Radio (cancel, exit 1):** Clears `TUI_RESULT`, prints nothing to stdout.
- **Yes/No (confirm, exit 0):** Prints literal string `'yes'` or `'no'` to stdout. Sets `TUI_RESULT` to the same string.
- **Yes/No (cancel, exit 1):** Clears `TUI_RESULT`, prints nothing to stdout.

### POSIX Compliance

- Zero bashisms verified: no `[[ ]]`, no `echo -e`, no `$'\033'`, no `let`, no `==` inside `[ ]`.
- All `eval`-based variable storage uses `sed "s/'/'\\''/g"` sanitization (per T-02-03 mitigation from Phase 2).
- Escape sequences use `ESC=$(printf '\033')` pattern.
- `shellcheck -s sh tui.sh` exits 0 with zero errors/warnings.
- Unicode glyphs `(•)`, `(○)`, `←→` are stored as literal UTF-8 bytes in the script. ASCII fallbacks `(*)`, `( )`, and text-based arrows (`Up/Dn`) are provided for non-UTF-8 terminals.

---

## Verification

| Check | Result |
|-------|--------|
| `shellcheck -s sh tui.sh` | PASS (exit 0, no warnings) |
| `sh -n tui.sh` | PASS (valid syntax) |
| `tui_radio()` exists | PASS (1 function definition) |
| `_tui_render_radio()` exists | PASS |
| `tui_yesno()` exists | PASS (1 function definition) |
| `_tui_render_yesno()` exists | PASS |
| `(•)` glyph | PASS (Unicode filled bullet) |
| `(○)` glyph | PASS (Unicode hollow circle) |
| `(*)` ASCII fallback | PASS |
| `( )` ASCII fallback | PASS |
| `--demo-radio` flag | PASS |
| `--demo-yesno` flag | PASS |
| Radio: SPACE select, ENTER confirm, Esc cancel | PASS (implemented in event loop) |
| Radio: `--default N` pre-selection | PASS |
| Radio: zero-selection guard | PASS ("Select an option" error) |
| Yes/No: Left/Right toggle, ENTER confirm | PASS |
| Yes/No: "No" pre-selected by default | PASS |
| Yes/No: returns 'yes'/'no' strings | PASS |
| Both widgets: fallback non-TTY prompts | PASS |
| All `_tr_*` / `_ty_*` variables cleaned up | PASS (all exit paths unset) |
| No bashisms | PASS |
| Threat mitigations | PASS (no new security surface per threat model) |

---

## Self-Check: PASSED

- [x] `tui.sh` exists and reflects all changes (1839+ lines)
- [x] Commit `2aaa294` exists (Task 1 — radio widget)
- [x] Commit `c9d8033` exists (Task 2 — yesno widget)
- [x] No file deletions in commits
- [x] ShellCheck clean
- [x] All acceptance criteria verified
