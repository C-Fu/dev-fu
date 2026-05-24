---
phase: 03-menu-system
reviewed: 2026-05-24T23:00:00Z
depth: deep
files_reviewed: 2
files_reviewed_list:
  - menu.sh
  - menu.db
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 03: Menu System Code Review Report

**Reviewed:** 2026-05-24
**Depth:** deep (cross-file analysis with tui.sh import graph tracing)
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Deep review of `menu.sh` (767 lines) and `menu.db` (16 lines) for Phase 3 (Menu System). Cross-referenced all dependencies on `tui.sh` (2144 lines). Focus areas: eval injection, terminal state consistency, variable scoping, signal safety, POSIX compliance, and DSL edge cases.

**Overall assessment:** The eval sanitization pattern (`sed "s/'/'\\\\''/g"`) is correct and handles all edge cases — including single-quote-only input, leading/trailing quotes, and shell injection payloads (`$(id)`, backticks). All four `tui_restore` exit paths are correct, and signal trap propagation (via `tui_init`) is sound. Zero bashisms detected (confirmed by `shellcheck -s sh` clean run).

**Key concerns:** One rendering bug (invisible top scroll indicator — pre-existing pattern from tui.sh), DSL parsing doesn't strip whitespace from fields, demo mode uses a relative path for `menu.db`, and empty action fields are silently accepted. No critical or blocker-level issues found.

---

## Warnings

### WR-01: Top scroll indicator rendered invisible — overwritten by item padding spaces

**File:** `menu.sh:350-353` (and identical pattern in `tui.sh:612-615`, `tui.sh:755-758`)

**Issue:** The top scroll indicator (`↑more`) is rendered at the same row as the first visible item BEFORE the item rendering loop writes that row. The item rendering loop's padding spaces (lines 371-380) extend from the end of the item label to the right border, overwriting columns 69-75 where the scroll indicator was placed.

Execution order:
1. Line 350-353: Scroll indicator placed at `$_fr_r`, column `$_fr_x + $_fr_box_w - 9` (≈col 69)
2. Line 366: `move_cursor "$_fr_r" "$_fr_x"` — same row, left edge (col 2)
3. Lines 367-382: Full item line written with padding spaces filling to col `$_fr_x + $_fr_inner` (≈col 76)

The padding spaces (step 3) overwrite the scroll indicator text (step 1). The indicator is never visible on screen. The bottom scroll indicator (lines 397-401) does NOT have this bug — it's rendered AFTER the item loop.

This bug is pre-existing in `_tui_render_select` and `_tui_render_checklist` (tui.sh); `_flu_menu_render` faithfully mirrors the broken pattern. Hidden in current test data: only 3 L1 items don't trigger scrolling.

**Fix:** Move the top scroll indicator AFTER the item rendering loop, OR render it on the separator row (`_fr_r - 1`) instead of the first item row. Similar fix needed in tui.sh.

```sh
# Option A: Render after item loop on a dedicated row before items
# (would need _fr_r decrement before item loop)
# Option B (simpler): Render at the top of the item area but use dedicated
# coordinates that the item loop won't overwrite — e.g., the separator row:
# move_cursor $((_fr_r - 1)) $((_fr_x + _fr_box_w - 9))
```

---

### WR-02: DSL fields are not trimmed — leading/trailing whitespace causes lookup mismatches

**File:** `menu.sh:68-69,77,102,125` (all `awk -F'|'` parsing sites)

**Issue:** The pipe-delimited DSL parser uses bare `awk -F'|' '{print $N}'` without trimming whitespace. A line like:
```
  Developer Tools | Languages | Python | install_python
```
produces fields `"  Developer Tools "`, `" Languages "`, etc. When the user navigates to `"Developer Tools"`, the exact-string comparison at line 184 (`[ "$_fm_entry_l1" = "$_fm_parent" ]`) fails because of leading/trailing spaces.

Verified: `echo "  L1  |  L2  |  L3  |action" | awk -F'|' '{print $1}'` → `"  L1  "` (untrimmed).

The shipped `menu.db` has no whitespace issues, so this only affects custom DSL files.

**Fix:** Add `gsub(/^[ \t]+|[ \t]+$/, "", $i)` to each awk print, or pre-process lines with a trim. Example:
```sh
_fm_l1=$(printf '%s' "$_fm_line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
```

---

### WR-03: Demo mode uses bare relative path for menu.db — fails when run from another directory

**File:** `menu.sh:755`

**Issue:** The demo handler sources `tui.sh` using a script-relative path (lines 750-752):
```sh
_menu_dir=$(cd "$(dirname "$0")" && pwd)
. "$_menu_dir/tui.sh"
```
But then calls `flu_menu_navigate "menu.db"` (line 755) with a bare filename. If the script is invoked as `sh /path/to/menu.sh --demo` from `/tmp`, `menu.db` won't be found.

```sh
# Current (broken when CWD != script dir):
flu_menu_navigate "menu.db"

# Should be:
flu_menu_navigate "$_menu_dir/menu.db"
```

**Fix:**
```sh
flu_menu_navigate "$_menu_dir/menu.db"
```

---

### WR-04: Empty action field (4th column) silently accepted — no validation

**File:** `menu.sh:275-292` (`flu_menu_get_action`)

**Issue:** `flu_menu_get_action()` returns the 4th field verbatim. For a DSL line like `Dev Tools|Languages|Python|`, the action is an empty string. No validation checks whether the action is non-empty before leaf selection. The caller at line 559 would output `Dev Tools|Languages|Python|` (trailing pipe with empty action), which downstream consumers (Phase 4) would need to handle gracefully.

Verified: `echo "Dev Tools|Languages|Python|" | awk -F'|' '{print $4}'` → empty string.

**Fix:** Consider validating at load time (in `flu_menu_load`) or at action retrieval:
```sh
# In flu_menu_get_action, after extracting:
if [ -z "$_fm_action" ]; then
  printf 'Warning: empty action for %s\n' "$_fm_path" >&2
  return 1
fi
```

---

### WR-05: Lines with fewer than 3 pipe-delimited fields produce empty child entries

**File:** `menu.sh:98-119,121-143` (L2/L3 unique list builders)

**Issue:** A malformed DSL line like `Dev Tools|Languages` (only 2 fields) produces:
- L2 entry: `"Dev Tools|Languages"` (correct)
- L3 entry: `"Dev Tools|Languages|"` — empty L3 segment with trailing pipe

When `flu_menu_get_children` for parent `"Dev Tools|Languages"` iterates the L3 list, it matches the prefix and extracts L3 as an empty string. This empty label would appear as a blank menu item.

Similarly, a 1-field line produces `"Dev Tools|"` in L2 with an empty L2 segment, yielding a blank L2 item under "Dev Tools".

**Fix:** Skip entries in L2/L3 lists where the child field is empty:
```sh
# In L2 builder (line 102):
_fm_l2_part=$(printf '%s' "$_fm_line" | awk -F'|' '{print $2}')
[ -z "$_fm_l2_part" ] && { _fm_i=$((_fm_i + 1)); continue; }
```

---

## Info

### IN-01: Redundant `2>/dev/null` redirections on `unset` commands

**File:** `menu.sh:623,652`

**Issue:** POSIX `unset` only errors on read-only variables — unsetting a nonexistent or already-unset variable succeeds silently. The `2>/dev/null` at lines 623 and 652 is unnecessary noise.

```sh
# Current (line 623, 652):
unset _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2 2>/dev/null

# Cleaner:
unset _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2
```

The `2>/dev/null` appears to be a defensive copy from contexts where stderr might matter, but here it's dead weight. Three other `unset` sites in the same function (lines 562-564, 613-615, 631-633) correctly omit it.

---

### IN-02: Scroll indicator uses `printf '%c'` with multi-byte UTF-8 arrow character

**File:** `menu.sh:352,400`

**Issue:** The scroll indicators use `printf '%cmore' '↑'` and `printf '%cmore' '↓'`. Per POSIX, `%c` with multi-byte arguments has unspecified behavior. On some shells (dash), `%c` may output only the first byte of the multi-byte sequence, producing garbage. In practice, most modern shells handle this correctly, and the box-drawing characters (`$TUI_BOX_*` variables) use `printf '%s'` (not `%c`), so they work fine. This is a pre-existing pattern from tui.sh.

**Fix:** Use `printf '%smore' '↑'` instead of `%c` — `%s` handles multi-byte characters correctly on all POSIX shells.

```sh
# Line 352: current
printf '%s%cmore%s' "$TUI_DIM" '↑' "$TUI_RESET"
# Fix:
printf '%s%smore%s' "$TUI_DIM" '↑' "$TUI_RESET"
```

---

### IN-03: O(n²) deduplication loops — fine for small DSL, slow for large files

**File:** `menu.sh:79-88,105-112,128-136`

**Issue:** The L1/L2/L3 unique-list builders use nested while loops for deduplication: for each input line (outer loop), scan all previously seen entries (inner loop). With N input lines, this is O(N²). For the 12-line `menu.db`, this is trivial. For a 1000-line custom DSL, it would be ~500k comparisons — still fine in shell, but worth noting.

**Fix (future):** If larger DSL files become common, consider building de-duplication via associative arrays in awk or pre-sorting.

---

### IN-04: DSL has no escape mechanism for pipe characters in labels

**File:** `menu.db` (format), `menu.sh` (all `awk -F'|'` calls)

**Issue:** A label like `"C|C++"` would be parsed as two separate fields by `awk -F'|'`, breaking the 3-level structure. This is a known DSL design limitation — the project requirement MENU-04 specifies "pipe-delimited DSL parseable with awk" and doesn't require pipe-escape support. If future use cases need pipes in labels, a backslash-escape (`\|`) or alternative delimiter would need to be added.

---

## Verified Correct

The following were examined in depth and found to be correct:

| Area | Finding |
|------|---------|
| **Eval sanitization** | `sed "s/'/'\\\\''/g"` correctly round-trips all edge cases: `'`, `it's`, `O'Brien's`, `$(id)`, `` `id` ``, `$HOME`, empty string. Verified with 11 test cases — all pass. |
| **Terminal state** | 4 `tui_restore()` calls: leaf-Enter (L557), leaf-Right (L609), empty-children error (L480), ESC-at-root (L629). All exit paths covered. |
| **Signal safety** | `tui_init` installs traps for INT/TERM/HUP/QUIT, each calls `tui_restore` before exit. Traps cleared on normal exit. |
| **Variable cleanup** | All `_fm_*` navigation state variables cleaned on every exit path. `_fr_*` render temp variables cleaned at end of `_flu_menu_render()`. |
| **POSIX compliance** | Zero bashisms. `shellcheck -s sh` clean. No `[[ ]]`, `echo -e`, `$'\033'`, `${var:0:1}`, `let`, `local`. `${1:-}` used on L742 is POSIX. |
| **KEY_LEFT dispatch** | Correctly handles both `_tui_read_key`-decoded `TUI_KEY_LEFT` (line 596-598) and ESC sub-read fallback (lines 583-589). |
| **KEY_RIGHT dispatch** | Correctly detected via ESC sub-read (line 590-592) and mapped to Enter-equivalent navigation. |
| **Back-navigation** | `awk -F'|' '{for(i=1;i<NF;i++)...}'` correctly strips last pipe segment for all depths. |
| **Fallback mode** | `_flu_menu_navigate_fallback()` provides full 3-level navigation with numbered prompts, EOF handling, input validation, and identical semantics. |

---

_Reviewed: 2026-05-24_
_Reviewer: OpenCode (gsd-code-reviewer)_
_Depth: deep_
