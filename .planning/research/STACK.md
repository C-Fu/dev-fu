# Technology Stack: Portable Shell-Script TUI Engine

**Project:** dev-fu / flu.sh — lxdialog-style TUI engine
**Researched:** 2026-05-23
**Mode:** Ecosystem (Stack dimension only)

---

## Executive Summary

The TUI engine is built entirely on ANSI/ECMA-48 escape sequences emitted via `printf`, single-byte key reads via `dd bs=1 </dev/tty`, and terminal mode control via `stty`. These three tools — `printf`, `dd`, `stty` — are universally available on every POSIX system including BusyBox, Alpine, Termux, and minimal containers. The existing `checklist.sh` (596 lines) already proves this approach works across dash, bash, zsh, and fish. The new lxdialog engine extends this proven foundation with additional widget types (menu, input, yesno, infobox, gauge) and a composable rendering architecture.

No external TUI libraries are used. No `dialog`, `whiptail`, `ncurses`, or `gum` binary is required or expected. The project constraint of zero dependencies is non-negotiable — this is a curl-pipe-bash tool that must work in minimal containers.

---

## Recommended Stack

### Core Tools (Required)

| Tool | Purpose | POSIX? | Availability | Confidence |
|------|---------|--------|--------------|------------|
| `printf` | Emit all ANSI escape sequences for rendering | Yes | Universal | HIGH |
| `dd bs=1 count=1` | Read single bytes from `/dev/tty` for key input | Yes | Universal (even BusyBox dd) | HIGH |
| `stty` | Raw terminal mode (`-echo -icanon`), save/restore | Yes | Universal (even BusyBox stty) | HIGH |
| `/dev/tty` | Direct TTY access (bypasses stdin pipe) | Yes | Universal | HIGH |

### Rendering — ANSI/ECMA-48 Escape Sequences

Every rendering operation is a `printf` emitting standard CSI (Control Sequence Introducer) sequences. These are verified against ECMA-48, VT100 reference (vt100.net), and the ncurses terminfo database.

#### Cursor Movement

| Operation | Escape Sequence | Example Code | Confidence |
|-----------|----------------|--------------|------------|
| Move to row R, col C | `\033[R;CH` | `printf '\033[%d;%dH' "$row" "$col"` | HIGH |
| Move up N lines | `\033[NA` | `printf '\033[%dA' "$n"` | HIGH |
| Move down N lines | `\033[NB` | `printf '\033[%dB' "$n"` | HIGH |
| Move right N cols | `\033[NC` | `printf '\033[%dC' "$n"` | HIGH |
| Move left N cols | `\033[ND` | `printf '\033[%dD' "$n"` | HIGH |
| Save cursor (DEC) | `\0337` | `printf '\0337'` | HIGH |
| Restore cursor (DEC) | `\0338` | `printf '\0338'` | HIGH |
| Save cursor (SCO) | `\033[s` | `printf '\033[s'` | HIGH |
| Restore cursor (SCO) | `\033[u` | `printf '\033[u'` | HIGH |
| Home (row 1, col 1) | `\033[H` | `printf '\033[H'` | HIGH |

**Recommendation:** Use `\033[R;CH` for all positioning. Do NOT use relative moves (`A/B/C/D`) for widget rendering — absolute positioning is simpler, less error-prone, and avoids cumulative drift bugs. Relative moves are acceptable for micro-adjustments within a single render pass.

#### Screen Operations

| Operation | Escape Sequence | Example Code | Confidence |
|-----------|----------------|--------------|------------|
| Clear entire screen | `\033[2J` | `printf '\033[2J\033[H'` | HIGH |
| Clear from cursor to end of line | `\033[K` | `printf '\033[K'` | HIGH |
| Clear from cursor to start of line | `\033[1K` | `printf '\033[1K'` | HIGH |
| Clear entire line | `\033[2K` | `printf '\033[2K'` | HIGH |
| Clear from cursor to end of screen | `\033[J` | `printf '\033[J'` | HIGH |
| Hide cursor | `\033[?25l` | `printf '\033[?25l'` | HIGH |
| Show cursor | `\033[?25h` | `printf '\033[?25h'` | HIGH |

#### Colors and Text Attributes

| Operation | Escape Sequence | Notes | Confidence |
|-----------|----------------|-------|------------|
| Reset all attributes | `\033[0m` | Always end styled runs with this | HIGH |
| Bold / bright | `\033[1m` | Widely supported | HIGH |
| Dim | `\033[2m` | Not universally supported; use sparingly | MEDIUM |
| Underline | `\033[4m` | Widely supported | HIGH |
| Reverse video | `\033[7m` | Primary highlight for cursor/selection | HIGH |
| Foreground color (0-7) | `\033[3Nm` | N = 0-7 (standard) | HIGH |
| Background color (0-7) | `\033[4Nm` | N = 0-7 (standard) | HIGH |
| Foreground 256-color | `\033[38;5;Nm` | N = 0-255; xterm-256color | HIGH |
| Background 256-color | `\033[48;5;Nm` | N = 0-255; xterm-256color | HIGH |
| Foreground truecolor | `\033[38;2;R;G;Bm` | R/G/B 0-255; not universal | MEDIUM |
| Background truecolor | `\033[48;2;R;G;Bm` | R/G/B 0-255; not universal | MEDIUM |

**Color strategy:** Use `\033[7m` (reverse video) as the primary selection highlight — it works on every terminal, even monochrome. Use standard 8-color (`\033[3Nm`/`\033[4Nm`) for accents. Reserve 256-color for optional eye-candy that degrades gracefully. Never depend on truecolor.

Standard 8-color palette (ANSI):

| N | Color | Use in TUI |
|---|-------|-----------|
| 0 | Black (default bg) | Background |
| 1 | Red | Errors, warnings |
| 2 | Green | Success, selected |
| 3 | Yellow | Highlights |
| 4 | Blue | Info, headers |
| 5 | Magenta | Accents |
| 6 | Cyan | Accents |
| 7 | White (default fg) | Normal text |

#### Advanced Features

| Operation | Escape Sequence | Portability | When to Use |
|-----------|----------------|-------------|-------------|
| Alternate screen buffer ON | `\033[?1049h` | xterm, most modern terminals | Optional; only if main screen must be preserved |
| Alternate screen buffer OFF | `\033[?1049l` | Same as above | Restore after TUI exits |
| Set scroll region | `\033[top;bottomr` | VT100+, universal in modern terminals | For scrollable content areas within widgets |
| Reset scroll region | `\033[r` | Same | Restore after use |
| Set cursor style (block) | `\033[?1c` or `\033[2 q` | Not universal | Optional enhancement |
| Set cursor style (bar) | `\033[5 q` | Not universal | Optional enhancement |

**Alternate screen buffer recommendation:** Do NOT use by default. It breaks scrollback history and confuses users in curl-pipe-bash scenarios. Only activate if the user explicitly requests it or if the existing codebase already uses it. The current `checklist.sh` does NOT use it, and this is the correct decision.

**Scroll region recommendation:** Use `\033[top;bottomr` for scrollable lists inside a fixed layout. This is essential for the menu widget where the list area scrolls while the title and footer stay fixed. Verified in terminfo as `csr=\E[%i%p1%d;%p2%dr`.

### Key Input — Reading Keyboard Without External Dependencies

This is the most critical and tricky part of the TUI engine. The approach differs fundamentally between POSIX sh and Bash.

#### The POSIX Way: `dd` + `/dev/tty`

```sh
# Read one byte from the controlling terminal
read_key() {
  key=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
  if [ "$key" = "$(printf '\033')" ]; then
    # Escape sequence: read 2 more bytes
    seq=$(dd bs=1 count=2 2>/dev/null </dev/tty || true)
    key="$key$seq"
  fi
  printf '%s' "$key"
}
```

**Why this works:**
- `dd bs=1 count=1` reads exactly one byte — POSIX guaranteed
- `/dev/tty` always refers to the controlling terminal, even when stdin is piped (critical for curl-pipe-bash)
- `2>/dev/null` suppresses dd's default "0+1 records in" status message
- `|| true` prevents dd's non-zero exit on some systems from aborting with `set -e`

**Limitations:**
- No timeout — `dd` blocks indefinitely waiting for input. This means no animated spinners or auto-refresh while waiting for keys.
- Escape key detection has a timing problem: pressing Escape sends a bare `\033`, but arrow keys start with `\033` too. The current approach reads 2 more bytes after `\033`, which works for known sequences but introduces a ~0.1s perceived lag when pressing bare Escape (because the terminal waits to see if more bytes follow).

**Confidence: HIGH** — This is exactly what the existing `checklist.sh` uses, proven across dash, ash, bash, zsh, BusyBox.

#### The Bash Way: `read -n` (NOT USED for portability)

```bash
# Bash-specific — do NOT use in POSIX TUI engine
IFS= read -rsn1 key
```

`read -n N` is a Bash extension (also in zsh, ksh). It is NOT POSIX. Since the project requires dash/ash/busybox sh compatibility, this approach is **not acceptable** for the core TUI engine.

**Decision:** Use `dd` + `/dev/tty` for all key reads. The `read -n` approach is documented here only for awareness.

#### Key Sequence Map

Verified against terminfo (ncurses 6.6 terminfo.src) and VT100 reference:

| Key | Sequence (normal mode) | Sequence (application mode) | POSIX Match Pattern |
|-----|----------------------|---------------------------|-------------------|
| Enter | `\n` (0x0A) or `\r` (0x0D) | same | `$'\n'` or `$'\r'` |
| Escape (bare) | `\033` (0x1B) | same | Must detect by timeout or 2-byte read returning empty |
| Space | ` ` (0x20) | same | `' '` |
| Backspace | `\x7F` (DEL) or `\x08` (BS) | same | `$'\x7f'` or `$'\b'` |
| Arrow Up | `\033[A` | `\033OA` | Both must be handled |
| Arrow Down | `\033[B` | `\033OB` | Both must be handled |
| Arrow Right | `\033[C` | `\033OC` | Both must be handled |
| Arrow Left | `\033[D` | `\033OD` | Both must be handled |
| Home | `\033[H` | `\033OH` | Handle both; may also be `\033[1~` on some terminals |
| End | `\033[F` | `\033OF` | Handle both; may also be `\033[4~` on some terminals |
| Page Up | `\033[5~` | same | `$'\033[5~'` |
| Page Down | `\033[6~` | same | `$'\033[6~'` |
| Delete | `\033[3~` | same | `$'\033[3~'` |
| Insert | `\033[2~` | same | `$'\033[2~'` |
| Tab | `\t` (0x09) | same | `$'\t'` |
| Ctrl-C | `\x03` | same | `$'\003'` |
| Ctrl-D | `\x04` | same | `$'\004'` |

**POSIX match patterns:** The `$'\xxx'` syntax is a Bashism. In POSIX sh, compare using:

```sh
# POSIX-compatible key matching
case "$key" in
  "$(printf '\n')") echo "Enter" ;;
  "$(printf '\r')") echo "Enter (CR)" ;;
  "$(printf '\033')") echo "Escape (bare)" ;;
  "$(printf '\033[A')") echo "Arrow Up" ;;
  "$(printf '\033OA')") echo "Arrow Up (app mode)" ;;
  ' ') echo "Space" ;;
  "$(printf '\x7f')") echo "Backspace (DEL)" ;;
  "$(printf '\b')") echo "Backspace (BS)" ;;
esac
```

**This is exactly the pattern used in the existing `checklist.sh`** and proven to work across all target shells.

**Confidence: HIGH** — Sequences verified against ncurses terminfo.src, VT100 reference, and existing working code.

#### Normal vs Application Cursor Key Mode

Terminals send different sequences for arrow keys depending on the cursor key mode:

| Mode | Arrow Up | Set Mode | Reset Mode |
|------|----------|----------|------------|
| Normal | `\033[A` | `\033[?1l` (DECCKM reset) | Default |
| Application | `\033OA` | `\033[?1h` (DECCKM set) | `\033[?1l` |

**Recommendation:** Do NOT switch to application mode. Stay in normal mode (the default). Handle both `\033[A` and `\033OA` forms in the key matcher as a defensive measure, but don't actively set application mode. The existing `checklist.sh` handles both and this is the right approach.

### Terminal Mode Control

#### Initialization Pattern

```sh
_term_saved_stty=

term_init() {
  _term_saved_stty=$(stty -g 2>/dev/null || true)
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  printf '\033[?25l'  # hide cursor
  trap 'term_restore; exit 1' INT TERM HUP
}
```

**Explanation:**
- `stty -g` saves current terminal settings as a string that `stty` can restore later. Works on Linux, macOS, FreeBSD. On systems where it fails (rare), the empty-string guard prevents `term_restore` from trying to restore nothing.
- `stty -echo -icanon` turns off echo (so our key reads don't appear on screen) and canonical mode (so we get raw bytes, not line-buffered input).
- `min 1 time 0` means: block until at least 1 byte is available, no timeout.
- `|| true` after each stty call prevents `set -e` from aborting if stty fails (e.g., no TTY).
- `trap` ensures terminal is restored even on signals.

#### Restoration Pattern

```sh
term_restore() {
  [ -n "$_term_saved_stty" ] && stty "$_term_saved_stty" 2>/dev/null || true
  printf '\033[?25h'  # show cursor
  trap - INT TERM HUP
}
```

**Critical:** This MUST be called before any `exit` or `return` from the TUI. The existing `checklist.sh` calls `term_restore` before both the success and cancel paths. This pattern must be replicated in every widget.

**Confidence: HIGH** — Proven in existing `checklist.sh` across all target shells.

### Terminal Size Detection

```sh
rows=$(tput lines 2>/dev/null || printf 24)
cols=$(tput cols 2>/dev/null || printf 80)
```

**Why `tput` and not raw escape sequences:**
- `tput lines`/`tput cols` reads from the terminfo database, which has already been configured for the terminal.
- The alternative, `\033[18t` (request terminal size — xterm extension), is NOT universally supported. It works in xterm and many modern terminals but NOT in screen, tmux without xterm-termcap, or the Linux console.
- `tput` may not be available in truly minimal containers (Alpine without `ncurses-terminfo-base`). The fallback values (24 rows, 80 cols) handle this.

**Alternative for when tput is unavailable:**

```sh
# Parse COLUMNS/LINES environment variables (set by some shells)
rows=${LINES:-24}
cols=${COLUMNS:-80}
```

**Recommendation:** Use `tput` with `COLUMNS`/`LINES` fallback, then hardcode 80x24 as final fallback.

**Confidence: HIGH**

### Terminal Resize Handling

```sh
# SIGWINCH is sent when terminal is resized
# POSIX trap supports signal names on most systems
trap 'handle_resize' WINCH

handle_resize() {
  rows=$(tput lines 2>/dev/null || printf 24)
  cols=$(tput cols 2>/dev/null || printf 80)
  # Re-render the current widget with new dimensions
  render
}
```

**Portability note:** `WINCH` in trap is POSIX but some very old shells may not support it. BusyBox ash supports it. Dash supports it. Bash and zsh support it. If WINCH trap is not available, the widget simply doesn't auto-resize — the user can manually trigger a re-render by pressing a key.

**Confidence: MEDIUM** — WINCH trap works on all target shells but the auto-rerender-on-resize is complex and can cause rendering glitches. Defer to a later enhancement.

### Box Drawing

#### ASCII Box Drawing (Primary — Universal)

```
+--+    +--+
|  |    |  |
+--+    +--+
```

Characters: `+`, `-`, `|`. Works on every terminal, every encoding, every font.

**This is the recommended approach** for the lxdialog engine. It matches the project's "Pure ANSI/ASCII" constraint.

#### Unicode Box Drawing (Secondary — Optional Enhancement)

```
┌──┐    ╔══╗
│  │    ║  ║
└──┘    ╚══╝
```

Characters: `┌ ─ ┐ │ └ ┘ ├ ┤ ┬ ┴ ┼` (U+2500-U+257F).

**Use ONLY when terminal supports UTF-8.** Detection:

```sh
# Check if terminal likely supports UTF-8
has_utf8() {
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) return 0 ;;
    *) return 1 ;;
  esac
}
```

**Recommendation:** Default to ASCII box drawing. Add Unicode box drawing as an optional enhancement that activates when `has_utf8` returns true AND the user hasn't set an explicit `ASCII_ONLY` flag. The existing `checklist.sh` uses ASCII only — maintain that default.

**Confidence: HIGH** for ASCII, MEDIUM for Unicode detection (the LANG/LC_CTYPE check is reliable but not perfect).

---

## POSIX vs Bash Boundaries

This is the most critical architectural decision. The TUI engine must work in POSIX sh (dash, ash, BusyBox sh), not just Bash.

### POSIX-Compatible (USE These)

| Feature | POSIX? | Notes |
|---------|--------|-------|
| `printf "\033[..."` | Yes | POSIX guarantees `\033` in format string |
| `dd bs=1 count=1` | Yes | POSIX dd |
| `stty -echo -icanon` | Yes | POSIX stty |
| `stty -g` / `stty "$saved"` | Yes | Works on Linux, macOS, BSD |
| `trap 'handler' INT TERM HUP` | Yes | POSIX trap |
| `case "$key" in ... esac` | Yes | POSIX pattern matching |
| `$(command substitution)` | Yes | POSIX command substitution |
| `[ -n "$var" ]` | Yes | POSIX test |
| `eval "var_$i=value"` | Yes | Dynamic variable names (used in checklist.sh) |
| `while / for / until` loops | Yes | POSIX |
| Shell functions | Yes | POSIX, but no `function` keyword |
| Local variables with `local` | Almost | Not strictly POSIX, but supported by dash, ash, BusyBox sh, bash, zsh |
| Arithmetic `$(( ))` | Yes | POSIX arithmetic expansion |
| `printf '%s' "$var"` | Yes | Safe printing without interpretation |

### Bash-Only (AVOID These in TUI Engine)

| Feature | Why Bash-Only | POSIX Alternative |
|---------|--------------|-------------------|
| `$'\033'` (dollar-single-quote) | Bash/ksh extension | `$(printf '\033')` |
| `read -n 1` | Bash extension | `dd bs=1 count=1 </dev/tty` |
| `read -s` | Bash extension | `stty -echo` |
| `read -t 0.1` | Bash extension | Not available (no timeout in POSIX) |
| `[[ ... ]]` | Bash extension | `[ ... ]` with proper quoting |
| Arrays `arr=(1 2 3)` | Bash extension | Newline-separated strings + `for` loop |
| `${arr[@]}` | Bash extension | `IFS='\\n'; set -- $string` |
| `function name { }` | Bash keyword | `name() { }` (POSIX function syntax) |
| `declare` / `typeset` | Bash builtins | Not needed; use `eval` for dynamic names |
| Process substitution `<(...)` | Bash extension | Not needed for TUI |
| `select` loop | Bash/Ksh | Build custom menu widget (that's the whole point) |
| `{1..10}` brace expansion | Bash extension | `seq 1 10` or while loop |
| `<<<` herestring | Bash extension | `echo "text" \| command` or pipe |

### The `local` Variable Gray Area

`local` is not in POSIX, but it works in dash, ash, BusyBox sh, bash, and zsh. The existing `checklist.sh` does NOT use `local` — it uses global variables with prefixed names. This is the safest approach for maximum portability.

**Recommendation:** Follow the existing `checklist.sh` pattern: use prefixed global variables (e.g., `_tui_cursor_row`, `_widget_selected`) rather than `local`. If `local` is used, it will work on all target shells but fails the strict POSIX test.

**Confidence: HIGH**

---

## What NOT to Use and Why

### Do NOT Use: `dialog` / `whiptail` / `lxdialog`

| Reason | Detail |
|--------|--------|
| External dependency | Not installed in minimal containers, Alpine, BusyBox environments |
| Inconsistent behavior | `dialog` and `whiptail` have different option syntax and output formats |
| GPL licensing | `dialog` is GPL; the project uses MIT license |
| Not curl-pipe-bash friendly | Requires installation before use |
| Subprocess overhead | Each widget call forks a new process |

**Why the existing project decided against them:** The PROJECT.md explicitly states "Pure ANSI/ASCII UI: No dialog, whiptail, ncurses, or other TUI libraries."

### Do NOT Use: ncurses / curses

| Reason | Detail |
|--------|--------|
| C library | Requires compilation; not a shell-level tool |
| `tput` is the only ncurses tool we use | And only for terminal size queries, with fallbacks |
| Overkill | We need ~15 escape sequences, not a full screen management library |

### Do NOT Use: `gum` (Charmbracelet)

| Reason | Detail |
|--------|--------|
| External Go binary | Must be downloaded and installed |
| Beautiful but not portable | Not in any package manager's base install |
| Defeats the zero-dependency goal | Project identity is curl-pipe-bash with no prerequisites |

`gum` is worth studying for UX inspiration (key bindings, styling, animations) but cannot be a dependency.

### Do NOT Use: `read -n` (Bash built-in)

| Reason | Detail |
|--------|--------|
| Not POSIX | Fails in dash, BusyBox ash |
| Project requires POSIX | Must work on dash, ash, busybox sh |

### Do NOT Use: `\033[?1049h` Alternate Screen Buffer (by default)

| Reason | Detail |
|--------|--------|
| Destroys scrollback | Users lose all previous output when TUI exits |
| Confusing for curl-pipe-bash | User expects to see what happened after the script finishes |
| Not universally supported | Some minimal terminals don't implement it |

**Exception:** Could be offered as an opt-in flag (`FLU_ALTSCREEN=1`) but never the default.

### Do NOT Use: Truecolor (`\033[38;2;R;G;Bm`)

| Reason | Detail |
|--------|--------|
| Not universally supported | Many terminals, especially in containers, don't support it |
| Adds complexity for no functional gain | 8-color is sufficient for a TUI menu system |

---

## Widget Rendering Architecture

### Recommended Pattern: Full Redraw on Input

The existing `checklist.sh` uses full redraw: `clear_screen` then redraw everything on each key press. This is the recommended approach for the lxdialog engine.

**Why full redraw (not incremental):**
1. **Simpler code** — no need to track dirty regions or compute diffs
2. **More reliable** — no risk of accumulated rendering drift
3. **Fast enough** — `printf` and escape sequences are extremely fast; a typical menu of 20 items renders in under 1ms
4. **Handles resize naturally** — just redraw with new dimensions
5. **Proven** — existing `checklist.sh` uses this and it works

**Why NOT incremental redraw:**
1. Complex diff logic in POSIX sh is error-prone
2. Race conditions with terminal resize
3. Harder to debug
4. The performance gain is negligible for the data volumes involved (menus, not real-time dashboards)

### Widget Types to Implement

| Widget | Description | Priority | Complexity |
|--------|-------------|----------|------------|
| `menu` | Single-select list with arrow navigation | P0 — Core | Medium |
| `checklist` | Multi-select list with space toggle | P0 — Already exists in `checklist.sh` | Done |
| `yesno` | Yes/No confirmation dialog | P0 — Core | Low |
| `inputbox` | Text input field | P1 | Medium |
| `infobox` | Non-blocking message display | P1 | Low |
| `gauge` | Progress bar | P2 | Medium |
| `radiolist` | Single-select from checklist-style list | P1 | Low (variant of checklist) |
| `textbox` | Scrollable text viewer | P2 | Medium |

### Widget Function Signature Convention

Following the existing `checklist.sh` pattern:

```sh
# All widgets follow this calling convention:
#   widget_type "title" "prompt" [options] [items...]
#
# Return codes:
#   0 = user confirmed/selected (result on stdout)
#   1 = user cancelled (Esc/q/Ctrl-C)

# Example: menu widget
tui_menu "Select Package" "Choose a package to install:" \
  "docker|Docker Engine" \
  "node|Node.js" \
  "go|Go (Golang)"

# Example: yesno widget
tui_yesno "Confirm Installation" "Install Docker Engine?" && install_docker
```

### Shared TUI Engine State Variables

```sh
# Prefix all globals with _tui_ to avoid collisions
_tui_saved_stty=""       # Saved terminal settings
_tui_rows=24             # Terminal rows
_tui_cols=80             # Terminal columns
_tui_cursor_row=0        # Current cursor row
_tui_cursor_col=0        # Current cursor col
```

---

## Supporting Patterns

### String Length Without ANSI Codes

```sh
# Strip ANSI escape sequences and get visible length
str_len() {
  _str=$(printf '%s' "$1" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
  printf '%s' "${#_str}"
}
```

This is needed for centering text, truncating labels, and computing box widths. The existing `checklist.sh` uses this pattern.

**Confidence: HIGH** — Proven in existing code.

### Label Truncation with Ellipsis

```sh
truncate_label() {
  _label=$1; _width=$2
  _clean=$(printf '%s' "$_label" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')
  _len=${#_clean}
  if [ "$_len" -le "$_width" ]; then
    printf '%s' "$_label"
  else
    _cutlen=$((_width - 1))
    printf '%s…' "$(printf '%s' "$_clean" | cut -c1-"$_cutlen")"
  fi
}
```

**Note:** The ellipsis `…` is a UTF-8 character (U+2026). In ASCII-only terminals, use `~` instead. Consider making this conditional on UTF-8 detection.

**Confidence: HIGH**

### Dumb Terminal Fallback

```sh
# When no TTY or TERM=dumb, fall back to numbered prompt
if [ ! -t 0 ] || [ "${TERM:-}" = "dumb" ]; then
  widget_fallback "$@"
  return $?
fi
```

This is essential for CI/CD, pipes, and screen readers. The existing `checklist.sh` has this pattern.

**Confidence: HIGH**

### Subprocess Safety

The TUI engine must handle signals correctly:

```sh
# On entry
term_init() {
  _term_saved_stty=$(stty -g 2>/dev/null || true)
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  printf '\033[?25l'
  trap 'term_restore; exit 130' INT TERM HUP
}

# On exit (every path!)
term_restore() {
  [ -n "$_term_saved_stty" ] && stty "$_term_saved_stty" 2>/dev/null || true
  printf '\033[?25h'
  trap - INT TERM HUP
}
```

**Critical pitfall:** If `term_restore` is not called before exiting, the user's terminal is left in raw mode with echo disabled. They'll see nothing when typing and need to run `stty sane` or `reset` to fix it. Every exit path (success, cancel, error, signal) must call `term_restore`.

**Confidence: HIGH**

---

## Sources

| Source | What It Verified | Confidence |
|--------|-----------------|------------|
| ECMA-48 standard (via Context7: /vi-k/ansi_escape_codes) | All CSI escape sequences, cursor movement, SGR attributes | HIGH |
| ncurses terminfo.src (invisible-island.net) | terminfo capability names, actual escape sequences for all terminal types, normal vs application cursor key modes | HIGH |
| VT100 User Guide (vt100.net/docs/vt100-ug/chapter3.html) | Historical origin of escape sequences, cursor key codes | HIGH |
| GNU Bash Manual (via Context7) | `read` builtin options, POSIX vs Bash boundaries | HIGH |
| Existing `checklist.sh` (596 lines, in repo) | Proven POSIX TUI patterns: dd key read, stty raw mode, ANSI rendering, dumb fallback | HIGH |
| Local terminal testing (xterm-256color, dash/bash) | Escape sequence verification, POSIX compatibility tests | HIGH |

---

## Summary of Recommendations

1. **Use `printf` + ANSI escape sequences** for ALL rendering. This is the only universal approach.
2. **Use `dd bs=1 count=1 </dev/tty`** for key input. Works in all POSIX shells.
3. **Use `stty -echo -icanon`** for raw terminal mode. Save/restore with `stty -g`.
4. **Use `\033[7m` (reverse video)** as primary selection highlight. Works everywhere.
5. **Use ASCII box drawing** (`+`, `-`, `|`) by default. Unicode is optional enhancement.
6. **Use full redraw** on each key press. Simpler, more reliable, fast enough.
7. **Handle both normal and application cursor key sequences** (`\033[A` AND `\033OA`).
8. **Fall back to numbered prompt** when no TTY or dumb terminal.
9. **Do NOT use alternate screen buffer** by default.
10. **Do NOT use Bash-only features** (`read -n`, `$'...'`, arrays, `[[ ]]`).

All recommendations are verified against at least two authoritative sources and the existing working codebase.
