---
phase: 01-tui-engine-core
reviewed: 2026-05-23T12:00:00Z
depth: deep
files_reviewed: 1
files_reviewed_list:
  - tui.sh
findings:
  critical: 2
  warning: 3
  info: 3
  total: 8
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-05-23
**Depth:** deep
**Files Reviewed:** 1
**Status:** issues_found

## Summary

Reviewed `tui.sh` (816 lines) — a portable POSIX TUI engine providing terminal primitives, signal-safe cleanup, shell-aware keyboard input, and a single-select menu widget. The code demonstrates strong POSIX discipline (no bashisms, `printf` everywhere, proper `$(( ))` arithmetic) and thoughtful design (shell-aware `read -rsn1` vs `dd`, configurable key timeout, proper `eval` sanitization).

**POSIX compliance**: Clean. No `$'\033'`, no `echo -e`, no `[[ ]]`, no `(( ))` without `$`, no `let`, no `typeset`. `dd` usage is read-only (`bs=1 count=1` only). Signal traps cover INT, TERM, HUP, and QUIT as required by INTG-04.

**Security**: The `eval` usage on lines 576 and 657 (dynamic variable names as POSIX array substitute) correctly sanitizes single quotes via `sed "s/'/'\\\\''/g"`. Tested with injection payloads (`'; echo PWNED; echo '`) — the escaping holds. Low risk per CONCERNS.md assessment.

**Critical issues found**: Two bugs that produce incorrect runtime behavior — an empty-item-list phantom selection and an arithmetic crash in the fallback prompt on POSIX shells (dash, busybox sh).

## Critical Issues

### CR-01: Empty item list allows phantom selection

**File:** `tui.sh:651-746`
**Issue:** When `tui_select` is called with zero items (e.g., `tui_select "Title" "Sub"`), `_ts_count` is 0 but `_ts_cursor` initializes to 1. The render loop produces no visible items (bounded by `_ts_end = min(scroll + page_size, count) = 0`), but the user can press Enter. The Enter handler at line 741-746 computes `_ts_idx = _ts_cursor - 1 = 0`, sets `TUI_RESULT=0`, prints `0` to stdout, and returns 0 (success). The caller receives a valid-looking selection for an item that doesn't exist.
**Fix:**
```sh
# In tui_select(), after the item-counting loop (after line 659):
if [ "$_ts_count" -eq 0 ]; then
  TUI_RESULT=''
  unset _ts_title _ts_subtitle _ts_count _ts_cursor _ts_scroll \
        _ts_show_help _ts_go_digits _ts_error_msg _ts_page_size
  return 1
fi
```

### CR-02: Leading zeros crash fallback prompt on POSIX shells

**File:** `tui.sh:442`
**Issue:** The fallback prompt converts the user's 1-based selection to a 0-based index using `$((_fb_selection - 1))`. POSIX `$(( ))` treats numbers with leading zeros as octal. If a user types `08` or `09` (valid decimal, invalid octal), the arithmetic expansion crashes on dash and busybox sh with `"Illegal number: 08"`. The `test -eq`/`-gt` comparisons on lines 428/435 handle leading zeros as decimal (they pass), so the crash occurs at the final conversion step — after all validation has passed.
**Fix:**
```sh
# Replace line 442 — strip leading zeros before arithmetic:
_fb_idx=$(( ${_fb_selection#"${_fb_selection%%[!0]*}"} - 1 ))
```
Or more readably:
```sh
# After line 425 validation, strip leading zeros:
while [ "${_fb_selection#0}" != "$_fb_selection" ] && [ "${#_fb_selection}" -gt 1 ]; do
  _fb_selection="${_fb_selection#0}"
done
_fb_idx=$((_fb_selection - 1))
```

## Warnings

### WR-01: TUI_RESULT not cleared on cancel

**File:** `tui.sh:748-751`
**Issue:** When the user cancels via Esc or Q, `tui_restore` is called and `return 1` is executed, but `TUI_RESULT` is not cleared. If a previous call to `tui_select` succeeded (setting `TUI_RESULT` to some index), a subsequent cancellation leaves `TUI_RESULT` holding the stale value. A caller that fails to check the return code will act on the wrong value.
**Fix:**
```sh
# In the ESC/Q handler (line 748-751):
"$TUI_KEY_ESC"|"$TUI_KEY_Q")
  tui_restore
  TUI_RESULT=''
  unset _ts_max_scroll _ts_bottom _ts_target _ts_go_digits _ts_error_msg
  return 1
  ;;
```

### WR-02: Dynamic label variables never freed

**File:** `tui.sh:653-659, 741-751`
**Issue:** `tui_select` creates dynamic variables `_ts_label_1`, `_ts_label_2`, ..., `_ts_label_N` via `eval` (line 657). These are never unset on any return path (lines 741-751 unset other `_ts_*` variables but not `_ts_label_*`). If `tui_select` is called multiple times:
1. First call with 10 items creates `_ts_label_1` through `_ts_label_10`
2. Second call with 5 items creates `_ts_label_1` through `_ts_label_5`
3. `_ts_label_6` through `_ts_label_10` persist as stale data

While the current render code only accesses labels up to `_ts_count` (so stale values are never read), this is a memory leak and a latent correctness risk if the API evolves.
**Fix:**
```sh
# At the top of tui_select(), before the item-counting loop:
_n=1
while eval "[ -n \"\${_ts_label_$_n:-}\" ]" 2>/dev/null; do
  unset "_ts_label_$_n"
  _n=$((_n + 1))
done
unset _n

# Or simpler: clean up on both exit paths (Enter and Esc/Q):
# After line 745 and line 750, add:
_n=1; while [ "$_n" -le "$_ts_count" ]; do unset "_ts_label_$_n"; _n=$((_n + 1)); done; unset _n
```

### WR-03: `_tui_rk_c2` variable leaked on unrecognized escape sequences

**File:** `tui.sh:286-368`
**Issue:** When an escape sequence starts with `ESC [` or `ESC O` (line 286) and the second continuation byte (`_tui_rk_c2`) doesn't match any case in the switch (lines 297-360), execution falls through `esac` to the "unrecognized escape sequence" handler at line 363-368. The unset at line 367 includes `_tui_key_timeout` and `_tui_rk_c1` but omits `_tui_rk_c2`. This leaks one shell variable per unrecognized escape sequence (e.g., `ESC [ 3` for the Delete key, `ESC [ 2` for Insert, or any xterm modified key like `ESC [ 1 ; 5 A`).
**Fix:**
```sh
# Line 367 — add _tui_rk_c2 to the unset:
unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
```

## Info

### IN-01: `_tui_draw_box` is unused dead code

**File:** `tui.sh:453-501`
**Issue:** The `_tui_draw_box` function (49 lines) is defined but never called anywhere in the codebase. `_tui_render_select` performs its own inline box drawing rather than delegating to this helper. If intended for future Phase 2 widgets, a comment should document this. Otherwise, it should be removed.
**Fix:** Either add a comment `# For Phase 2 widget use` or remove the function.

### IN-02: Dead code branch in `_tui_fallback_prompt`

**File:** `tui.sh:420-424`
**Issue:** The `''` case at line 420 is unreachable. The empty-string check at line 408 (`if [ -z "$_fb_selection" ]`) already returns 1 before the `case` statement is reached. The `''` branch can never execute.
**Fix:** Remove the unreachable case branch:
```sh
case "$_fb_selection" in
  *[!0-9]*)
    printf 'Invalid input: not a number\n'
    unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
    return 1
    ;;
esac
```

### IN-03: Repetitive unset blocks in `_tui_read_key`

**File:** `tui.sh:214-373`
**Issue:** The same 7-variable unset statement (`_tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del`) is repeated 13 times across every return path in `_tui_read_key`. This could be extracted into a cleanup helper or the function could use a trap-based cleanup pattern. Not a functional issue, but increases maintenance burden — any new variable added to the function must be added to all 13 unset sites.
**Fix:** Consider a cleanup function:
```sh
_tui_rk_cleanup() {
  unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
}
```
Then call `_tui_rk_cleanup` before each `return`.

---

_Reviewed: 2026-05-23T12:00:00Z_
_Reviewer: OpenCode (gsd-code-reviewer)_
_Depth: deep_
