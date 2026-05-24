---
phase: 01-tui-engine-core
verified: 2026-05-23T04:15:00Z
status: human_needed
score: 5/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run `sh tui.sh --demo` in an interactive terminal and navigate with Up/Down arrows, j/k vi keys, PgUp/PgDn, Home/End through 25 items — verify reverse-video highlight moves and scroll indicators (↑more/↓more) appear when content overflows viewport"
    expected: "Cursor highlights one item at a time with reverse video; ↑more appears at top when scrolled down; ↓more appears at bottom when items extend beyond viewport; j/k behave identically to arrows; PgUp/PgDn jump pages; Home/End jump to first/last"
    why_human: "Requires interactive TTY terminal with real keyboard input — automated checks can only verify code structure, not visual rendering or key response behavior"
  - test: "In demo, type multi-digit number (e.g. '15') — verify status line shows 'Go to: 1_' then 'Go to: 15_' and cursor jumps to item 15 after timeout/non-digit key"
    expected: "Number accumulator displays visual feedback in status line; cursor jumps to the typed item number; out-of-range numbers show 'Item N not found' error"
    why_human: "Requires interactive terminal to observe real-time number accumulator behavior and visual feedback"
  - test: "In demo, press Ctrl-C — verify terminal state is fully restored (echo, cursor visible, normal line buffering)"
    expected: "No lingering raw mode; cursor visible; typing works normally; exit code 130"
    why_human: "Requires interactive terminal to verify signal handling leaves terminal in clean state"
  - test: "In demo, press '?' to toggle help footer — verify minimal footer expands to full keybinding list and back"
    expected: "Minimal footer shows 'Up/Dn Move Enter Select Esc Cancel ? Keys'; full footer shows all keybindings including PgUp/PgDn, j/k Vi, 0-9 Jump"
    why_human: "Visual rendering verification in interactive terminal"
  - test: "Test on dash or busybox sh: run `dash tui.sh --demo` or `busybox sh tui.sh --demo` — verify TUI works identically"
    expected: "Same visual rendering, same key response, terminal state restored on exit"
    why_human: "Cross-shell testing requires alternate shells installed and interactive terminal access"
---

# Phase 1: TUI Engine Core Verification Report

**Phase Goal:** Developer has a fully portable, POSIX-compliant TUI engine that renders interactive single-select menus with keyboard navigation, working identically across bash, zsh, dash, ash, and busybox sh
**Verified:** 2026-05-23T04:15:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can navigate a list of 20+ items using Up/Down arrows, j/k vi keys, PgUp/PgDn, and Home/End — seeing reverse-video highlight and scroll indicators (↑more/↓more) when content overflows | ✓ VERIFIED | Key dispatch handles all: TUI_KEY_UP/DOWN/PgUP/PgDN/HOME/END + j/k (lines 242-259, 701-745). Reverse video TUI_REV applied to cursor (line 584). Scroll indicators ↑more/↓more rendered conditionally (lines 566-611). Demo provides 25 items (lines 800-808). |
| 2 | User can select an item with Enter, cancel with Esc or q, and jump directly to any item by typing its number (multi-digit accumulator) | ✓ VERIFIED | Enter returns exit 0 + prints 0-based index + sets TUI_RESULT (lines 747-753). Esc/q returns exit 1 (lines 754-758). Number jump accumulator with digit char, auto-flush on non-digit, visual feedback "Go to: N_" (lines 619-620, 685-697, 767-785). Out-of-range error (lines 695, 783). |
| 3 | Script displays a numbered text prompt instead of TUI when TERM=dumb or no TTY is available | ✓ VERIFIED | `_tui_check_tty()` sets `_tui_use_tui=false` on TERM=dumb or no /dev/tty (lines 77-92). `tui_select()` delegates to `_tui_fallback_prompt()` (line 674-677). Behavioral test: `TERM=dumb sh tui.sh --demo` prints 25 numbered items, accepts input, returns exit codes correctly. Selection prints "Selected index: 0", cancel returns exit 1, invalid shows error. |
| 4 | Every screen shows a contextual help footer listing available keybindings | ✓ VERIFIED | Help footer rendered at footer row (lines 632-638). Minimal: 'Up/Dn Move Enter Select Esc Cancel ? Keys'. Full (toggled by ?): 'Up/Dn Move Enter Select Esc/q Cancel PgUp/PgDn Page Home/End j/k Vi ? Help 0-9 Jump'. Toggle logic at lines 761-765. |
| 5 | Terminal state is fully restored on every exit path including Ctrl-C and signals (INT, TERM, HUP, QUIT) | ✓ VERIFIED | `tui_init()` registers traps for INT (exit 130), TERM (exit 143), HUP (exit 129), QUIT (exit 131) — all call tui_restore (lines 109-112). `tui_restore()` restores stty from saved state, shows cursor, clears all 4 traps (lines 115-122). Enter exit path calls tui_restore (line 747). Esc/q exit path calls tui_restore (line 755). Double-restore prevented by clearing `_tui_saved_stty` (line 121). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tui.sh` | Complete POSIX TUI engine (min 400 lines) | ✓ VERIFIED | 823 lines. Contains all required functions. Sourceable in POSIX sh. shellcheck -s sh passes clean. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `tui_select()` | `_tui_read_key()` | Main event loop reads keys | ✓ WIRED | `key=$(_tui_read_key)` at line 683 in while loop |
| `tui_select()` | `tui_init()` / `tui_restore()` | Terminal setup/restore on every exit path | ✓ WIRED | `tui_init` at line 679; `tui_restore` at lines 747, 755; signal traps at lines 109-112 |
| `tui_select()` | stdout | Prints 0-based selected index | ✓ WIRED | `printf '%d\n' "$_ts_idx"` at line 750 |
| `tui_select()` | `_tui_fallback_prompt()` | Delegates when `_tui_use_tui` is false | ✓ WIRED | `_tui_fallback_prompt "$_ts_title" "$_ts_subtitle" "$@"` at line 675 |
| `tui_init()` | Signal handlers | Trap registration for INT/TERM/HUP/QUIT | ✓ WIRED | Lines 109-112: all 4 signals trapped to call `tui_restore` then exit |
| `_tui_read_key()` | `/dev/tty` | dd or read -rsn1 | ✓ WIRED | `_tui_read_byte()` uses `read -rsn1 </dev/tty` (bash/zsh) or `dd bs=1 count=1 </dev/tty` (POSIX) |
| `tui_init()` | `stty` | Terminal state save/restore | ✓ WIRED | `stty -g` save at line 105; `stty "$_tui_saved_stty"` restore at line 117 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `_tui_render_select()` | `_ts_label_N` via eval | Item labels passed by caller via eval storage | ✓ FLOWING | Items stored at lines 656-661 via sed-sanitized eval; retrieved at line 578 via `eval "_rs_lab=\$_ts_label_$_rs_i"` |
| `_tui_render_select()` | `_ts_cursor` / `_ts_scroll` | Navigation state modified by key dispatch in main loop | ✓ FLOWING | Set initially (lines 667-668), modified in case dispatch (lines 701-787), consumed by render (lines 566-598) |
| `_tui_render_select()` | `_rs_rows` / `_rs_cols` | `tput lines` / `tput cols` with fallback defaults | ✓ FLOWING | Lines 512-513: real terminal dimensions with defaults (24/80) |
| `tui_select()` (Enter path) | `TUI_RESULT` | Computed from `_ts_cursor - 1` | ✓ FLOWING | Line 749: `TUI_RESULT=$_ts_idx` where `_ts_idx=$((_ts_cursor - 1))` |
| `_tui_fallback_prompt()` | `TUI_RESULT` | Computed from validated user input | ✓ FLOWING | Line 446: `TUI_RESULT="$_fb_idx"` where `_fb_idx=$((_fb_selection - 1))` |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| shellcheck passes | `/tmp/opencode/shellcheck -s sh tui.sh` | Exit code 0, no output | ✓ PASS |
| Sourceable in POSIX sh | `sh -c '. ./tui.sh && type tui_select && type tui_init && type tui_restore'` | All 10 functions found | ✓ PASS |
| Fallback mode (TERM=dumb) shows 25 numbered items | `printf '' \| TERM=dumb sh tui.sh --demo 2>&1 \| grep -c '^[[:space:]]*[0-9]'` | 26 (25 items + "25)" line counted) | ✓ PASS |
| Fallback selection returns exit 0 + index | `printf '1\n' \| TERM=dumb sh tui.sh --demo 2>&1` | "Selected index: 0 (TUI_RESULT=0)", exit 0 | ✓ PASS |
| Fallback cancel returns exit 1 | `printf '\n' \| TERM=dumb sh tui.sh --demo 2>&1` | "Cancelled", exit 1 | ✓ PASS |
| Fallback invalid number shows error | `printf '99\n' \| TERM=dumb sh tui.sh --demo 2>&1` | "Invalid selection", exit 1 | ✓ PASS |
| Fallback non-numeric shows error | `printf 'abc\n' \| TERM=dumb sh tui.sh --demo 2>&1` | "Invalid input: not a number", exit 1 | ✓ PASS |
| QUIT signal trap present | `grep -c 'QUIT' tui.sh` | 2 (trap line + trap - reset line) | ✓ PASS |
| No bashisms ($'\033', echo -e, [[ ]], let) | grep for each pattern | All return 0 matches | ✓ PASS |
| dd read-only (no of=, seek=, conv=) | `grep -c 'dd.*of=' tui.sh` | 0 | ✓ PASS |
| TUI_RESULT set on selection | `grep -c 'TUI_RESULT' tui.sh` | 5 references (doc, fallback set, tui_select set, cancel clear, demo print) | ✓ PASS |
| tui_restore on all exit paths | `grep -n 'tui_restore' tui.sh` | 8 references: definition, 4 traps, Enter path, Esc/q path, usage comment | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ENGN-01 | 01-02 | Up/Down arrows + j/k vi key navigation | ✓ SATISFIED | Key dispatch: lines 701-718 (UP/DOWN), key reading: j→TUI_KEY_DOWN (line 243), k→TUI_KEY_UP (line 248) |
| ENGN-02 | 01-02 | Enter to select, Esc/q to cancel | ✓ SATISFIED | Enter: exit 0 + index (lines 747-753). Esc/q: exit 1 (lines 754-758) |
| ENGN-03 | 01-02 | Reverse-video highlight (`\033[7m`) | ✓ SATISFIED | TUI_REV="${ESC}[7m" (line 35), applied to cursor item (line 584) |
| ENGN-04 | 01-02 | Scroll indicators ↑more/↓more | ✓ SATISFIED | Conditional rendering: ↑more (lines 566-569), ↓more (lines 608-612) |
| ENGN-05 | 01-02 | PgUp/PgDn pagination | ✓ SATISFIED | Key dispatch: lines 720-735 |
| ENGN-06 | 01-02 | Home/End jump to first/last | ✓ SATISFIED | Key dispatch: lines 736-745. Also vi-style g/G (lines 253-259) |
| ENGN-07 | 01-02 | Number jump (multi-digit accumulator) | ✓ SATISFIED | Accumulator `_ts_go_digits` (lines 768-785), auto-flush on non-digit (lines 685-698), visual feedback (line 620) |
| ENGN-08 | 01-01 | Numbered text fallback when TERM=dumb or no TTY | ✓ SATISFIED | `_tui_fallback_prompt()` (lines 384-449). Behavioral test confirmed. |
| WDGT-04 | 01-02 | Contextual help footer | ✓ SATISFIED | Footer at lines 632-638, toggle with ? (lines 761-765) |
| INTG-03 | 01-01 | POSIX sh compatible (bash, zsh, dash, ash, busybox) | ✓ SATISFIED | shellcheck -s sh passes. Shell-aware branching via `_tui_has_read_n`. No bashisms detected. Cross-shell testing requires human verification. |
| INTG-04 | 01-01 | Terminal state restored on every exit path (INT, TERM, HUP, QUIT) | ✓ SATISFIED | 4-signal traps (lines 109-112), tui_restore on Enter/Esc/q paths (lines 747, 755), double-restore prevention (line 121) |

**No orphaned requirements.** All 11 ROADMAP Phase 1 requirements are covered by plans and verified in code.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TODO/FIXME/placeholder/stub/empty-impl patterns found |

No anti-patterns detected. No `echo -e`, no `$'\033'`, no `[[ ]]`, no `let`, no `dd` write flags. Code is clean POSIX sh throughout.

### Human Verification Required

### 1. Interactive Navigation Test

**Test:** Run `sh tui.sh --demo` in an interactive terminal. Navigate using Up/Down arrows, j/k vi keys, PgUp/PgDn, and Home/End through the 25-item list.
**Expected:** Reverse-video highlight moves one item at a time with arrows/j/k. PgUp/PgDn jump pages. Home/End jump to first/last. Scroll indicators (↑more/↓more) appear when content overflows viewport.
**Why human:** Requires interactive TTY terminal with real keyboard input and visual rendering.

### 2. Number Jump Accumulator Test

**Test:** In the demo, type a multi-digit number (e.g., "15") without pressing Enter. Observe status line feedback.
**Expected:** Status line shows "Go to: 1_" then "Go to: 15_". After timeout or non-digit key, cursor jumps to item 15. Typing an out-of-range number (e.g., "99") shows "Item 99 not found" error flash.
**Why human:** Real-time number accumulator behavior and visual feedback require interactive terminal.

### 3. Signal Handling / Terminal Restore Test

**Test:** Run `sh tui.sh --demo` and press Ctrl-C during navigation.
**Expected:** Terminal state fully restored — echo works, cursor visible, normal line buffering. Exit code 130.
**Why human:** Terminal state verification requires interactive session and post-interruption shell observation.

### 4. Help Footer Toggle Test

**Test:** In the demo, press `?` to toggle help footer. Press again to toggle back.
**Expected:** Minimal footer "Up/Dn Move  Enter Select  Esc Cancel  ? Keys" expands to full footer with all keybindings. Pressing `?` again returns to minimal.
**Why human:** Visual rendering verification requires interactive terminal.

### 5. Cross-Shell Compatibility Test

**Test:** Run `dash tui.sh --demo` and/or `busybox sh tui.sh --demo` and verify identical behavior to bash.
**Expected:** Same visual rendering, same key response, terminal state restored on exit. Key reading uses `dd` path instead of `read -rsn1`.
**Why human:** Requires alternate shells installed and interactive terminal access. Code structure verified (shell-aware branching), but runtime behavior needs human confirmation.

### Gaps Summary

**No code-level gaps found.** All 5 ROADMAP success criteria have strong codebase evidence:

1. **Navigation** (SC-1): Full key dispatch for Up/Down/PgUp/PgDn/Home/End/j/k. Reverse video on cursor. Conditional scroll indicators. 25-item demo.
2. **Selection/cancel/number jump** (SC-2): Enter→exit 0+index, Esc/q→exit 1, multi-digit accumulator with auto-flush and visual feedback.
3. **Fallback prompt** (SC-3): `_tui_fallback_prompt()` activates on TERM=dumb or no TTY. Behavioral tests confirm correct behavior.
4. **Help footer** (SC-4): Contextual footer with `?` toggle between minimal and full keybinding display.
5. **Terminal restore** (SC-5): 4-signal traps (INT/TERM/HUP/QUIT) + restore on Enter/Esc/q exit paths. Double-restore prevention.

However, **human verification is required** for 5 items that cannot be tested programmatically — all involve interactive terminal behavior (visual rendering, real keyboard input, signal handling, cross-shell testing). The automated verification confirms all code structure, wiring, data flow, and behavioral tests (where possible) are correct.

---

_Verified: 2026-05-23T04:15:00Z_
_Verifier: OpenCode (gsd-verifier)_
