#!/usr/bin/env sh
# tui.sh — Portable POSIX TUI engine
#
# Terminal primitives, signal-safe cleanup, shell-aware keyboard input,
# and fallback numbered prompt. Works on bash, zsh, dash, ash, busybox sh.
#
# Usage:
#   . ./tui.sh
#   tui_init
#   # ... interactive TUI operations ...
#   tui_restore
#
# No external dependencies. No bashisms. Every line passes shellcheck -s sh.
#
# shellcheck disable=SC2034  # Library constants are used by callers who source this file

# ---------------------------------------------------------------------------
# Section 1: Shell detection
# ---------------------------------------------------------------------------

_tui_has_read_n=false
if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
  _tui_has_read_n=true
fi

# ---------------------------------------------------------------------------
# Section 2: Color / style constants
# ---------------------------------------------------------------------------

ESC=$(printf '\033')

TUI_RESET="${ESC}[0m"
TUI_BOLD="${ESC}[1m"
TUI_DIM="${ESC}[2m"
TUI_REV="${ESC}[7m"
TUI_RED="${ESC}[31m"
TUI_GREEN="${ESC}[32m"
TUI_YELLOW="${ESC}[33m"
TUI_CYAN="${ESC}[36m"
TUI_WHITE="${ESC}[37m"

# ---------------------------------------------------------------------------
# Section 3: Box-drawing character auto-detection
# ---------------------------------------------------------------------------

_tui_detect_box_chars() {
  _locale="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
  case "$_locale" in
    *UTF-8* | *utf-8* | *utf8* | *UTF8*)
      TUI_BOX_TL='┌'
      TUI_BOX_TR='┐'
      TUI_BOX_BL='└'
      TUI_BOX_BR='┘'
      TUI_BOX_H='─'
      TUI_BOX_V='│'
      ;;
    *)
      TUI_BOX_TL='+'
      TUI_BOX_TR='+'
      TUI_BOX_BL='+'
      TUI_BOX_BR='+'
      TUI_BOX_H='-'
      TUI_BOX_V='|'
      ;;
  esac
  unset _locale
}

_tui_detect_box_chars

# ---------------------------------------------------------------------------
# Section 4: TTY / terminal availability check
# ---------------------------------------------------------------------------

_tui_use_tui=true

_tui_check_tty() {
  if [ ! -c /dev/tty ]; then
    _tui_use_tui=false
    return
  fi
  if [ "${TERM:-}" = "dumb" ]; then
    _tui_use_tui=false
    return
  fi
  if [ ! -t 0 ]; then
    _tui_use_tui=false
    return
  fi
}

_tui_check_tty

# ---------------------------------------------------------------------------
# Section 5: Terminal init / restore
# ---------------------------------------------------------------------------

_tui_saved_stty=''

tui_init() {
  if [ "$_tui_use_tui" = "false" ]; then
    return
  fi

  _tui_saved_stty=$(stty -g 2>/dev/null || true)
  stty -echo -icanon min 1 time 0 2>/dev/null || true
  printf '%s[?25l' "$ESC"

  trap 'tui_restore; exit 130' INT
  trap 'tui_restore; exit 143' TERM
  trap 'tui_restore; exit 129' HUP
  trap 'tui_restore; exit 131' QUIT
}

tui_restore() {
  if [ -n "$_tui_saved_stty" ]; then
    stty "$_tui_saved_stty" 2>/dev/null || true
  fi
  printf '%s[?25h' "$ESC"
  trap - INT TERM HUP QUIT
  _tui_saved_stty=''
}

# ---------------------------------------------------------------------------
# Section 6: Rendering primitives
# ---------------------------------------------------------------------------

move_cursor() {
  # move_cursor row col
  printf '%s[%s;%sH' "$ESC" "$1" "$2"
}

clear_screen() {
  printf '%s[2J%s[H' "$ESC" "$ESC"
}

_tui_clear_line() {
  printf '%s[2K%s[1G' "$ESC" "$ESC"
}

_tui_printf_at() {
  # _tui_printf_at row col format [args...]
  _tui_pa_row="$1"; shift
  _tui_pa_col="$1"; shift
  move_cursor "$_tui_pa_row" "$_tui_pa_col"
  # shellcheck disable=SC2059  # Format string comes from caller — this is a printf wrapper
  printf "$@"
  unset _tui_pa_row _tui_pa_col
}

# ---------------------------------------------------------------------------
# Section 7: Key name constants
# ---------------------------------------------------------------------------

TUI_KEY_UP="up"
TUI_KEY_DOWN="down"
TUI_KEY_LEFT="left"
TUI_KEY_RIGHT="right"
TUI_KEY_ENTER="enter"
TUI_KEY_ESC="esc"
TUI_KEY_PGUP="pgup"
TUI_KEY_PGDN="pgdn"
TUI_KEY_HOME="home"
TUI_KEY_END="end"
TUI_KEY_SPACE="space"
TUI_KEY_TAB="tab"
TUI_KEY_BACKSPACE="backspace"
TUI_KEY_Q="q"
TUI_KEY_HELP="help"
TUI_KEY_NUMBER="number"
TUI_KEY_UNKNOWN="unknown"

# ---------------------------------------------------------------------------
# Section 8: Shell-aware key reading
# ---------------------------------------------------------------------------

# Read a single raw byte from /dev/tty.
# Uses read -rsn1 on bash/zsh (no process spawn), dd on POSIX shells.
# Prints the byte to stdout. Returns 0 on success, 1 on failure (EOF).
_tui_read_byte() {
  _tui_rb_byte=''
  if [ "$_tui_has_read_n" = "true" ]; then
    # shellcheck disable=SC3045  # -s is bash/zsh only; guarded by _tui_has_read_n check
    IFS= read -rsn1 _tui_rb_byte 2>/dev/null </dev/tty || true
  else
    _tui_rb_byte=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
  fi
  if [ -z "$_tui_rb_byte" ]; then
    unset _tui_rb_byte
    return 1
  fi
  printf '%s' "$_tui_rb_byte"
  unset _tui_rb_byte
  return 0
}

# High-level key reader with escape sequence parsing.
# Returns a symbolic key name string via stdout.
# Sets _tui_digit_char when returning TUI_KEY_NUMBER.
_tui_read_key() {
  _tui_rk_byte=$(_tui_read_byte) || { printf '%s' "$TUI_KEY_UNKNOWN"; return; }

  _tui_rk_nl=$(printf '\n')
  _tui_rk_cr=$(printf '\r')
  _tui_rk_esc=$(printf '\033')
  _tui_rk_tab=$(printf '\t')
  _tui_rk_bs=$(printf '\010')    # 0x08 BS
  _tui_rk_del=$(printf '\177')   # 0x7f DEL

  # Simple single-character keys
  case "$_tui_rk_byte" in
    "$_tui_rk_nl" | "$_tui_rk_cr")
      printf '%s' "$TUI_KEY_ENTER"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    ' ')
      printf '%s' "$TUI_KEY_SPACE"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    "$_tui_rk_tab")
      printf '%s' "$TUI_KEY_TAB"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    "$_tui_rk_del" | "$_tui_rk_bs")
      printf '%s' "$TUI_KEY_BACKSPACE"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    'q' | 'Q')
      printf '%s' "$TUI_KEY_Q"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    '?')
      printf '%s' "$TUI_KEY_HELP"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    'j')
      printf '%s' "$TUI_KEY_DOWN"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    'k')
      printf '%s' "$TUI_KEY_UP"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    'G')
      printf '%s' "$TUI_KEY_END"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    'g')
      printf '%s' "$TUI_KEY_HOME"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
    [0-9])
      _tui_digit_char="$_tui_rk_byte"
      printf '%s' "$TUI_KEY_NUMBER"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      return
      ;;
  esac

  # Escape sequence parsing
  if [ "$_tui_rk_byte" = "$_tui_rk_esc" ]; then
    _tui_key_timeout=${TUI_KEY_TIMEOUT:-10}  # deciseconds, default 100ms
    stty min 0 time "$_tui_key_timeout" 2>/dev/null || true

    _tui_rk_c1=$(_tui_read_byte) || _tui_rk_c1=''

    if [ -z "$_tui_rk_c1" ]; then
      # Bare Esc keypress — no continuation byte within timeout
      stty min 1 time 0 2>/dev/null || true
      printf '%s' "$TUI_KEY_ESC"
      unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
      unset _tui_key_timeout _tui_rk_c1
      return
    fi

    if [ "$_tui_rk_c1" = '[' ] || [ "$_tui_rk_c1" = 'O' ]; then
      _tui_rk_c2=$(_tui_read_byte) || _tui_rk_c2=''
      if [ -z "$_tui_rk_c2" ]; then
        stty min 1 time 0 2>/dev/null || true
        printf '%s' "$TUI_KEY_UNKNOWN"
        unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
        unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
        return
      fi

      # Parse based on second continuation byte
      case "$_tui_rk_c2" in
        A)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_UP"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        B)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_DOWN"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        C)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_RIGHT"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        D)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_LEFT"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        H)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_HOME"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        F)
          stty min 1 time 0 2>/dev/null || true
          printf '%s' "$TUI_KEY_END"
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
          ;;
        1 | 4 | 5 | 6)
          # 3-byte sequences: ESC [ N ~
          # 1~ = home, 4~ = end, 5~ = pgup, 6~ = pgdn
          _tui_rk_c3=$(_tui_read_byte) || _tui_rk_c3=''
          stty min 1 time 0 2>/dev/null || true
          if [ "$_tui_rk_c3" = '~' ]; then
            case "$_tui_rk_c2" in
              5) printf '%s' "$TUI_KEY_PGUP" ;;
              6) printf '%s' "$TUI_KEY_PGDN" ;;
              1) printf '%s' "$TUI_KEY_HOME" ;;
              4) printf '%s' "$TUI_KEY_END" ;;
              *)  printf '%s' "$TUI_KEY_UNKNOWN" ;;
            esac
          else
            printf '%s' "$TUI_KEY_UNKNOWN"
          fi
          unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2 _tui_rk_c3
          return
          ;;
      esac
    fi

    # Unrecognized escape sequence — discard and return unknown
    stty min 1 time 0 2>/dev/null || true
    printf '%s' "$TUI_KEY_UNKNOWN"
    unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
    unset _tui_key_timeout _tui_rk_c1
    return
  fi

  # Any other single byte not matched above
  printf '%s' "$TUI_KEY_UNKNOWN"
  unset _tui_rk_byte _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
}

# ---------------------------------------------------------------------------
# Section 9: Fallback numbered prompt
# ---------------------------------------------------------------------------

# _tui_fallback_prompt title subtitle item1 item2 ...
# Prints 0-based index of selected item to stdout.
# Sets TUI_RESULT to the same value.
# Returns 0 on selection, 1 on cancel/invalid.
_tui_fallback_prompt() {
  _fb_title="$1"; shift
  _fb_subtitle="$1"; shift
  _fb_count=$#
  _fb_i=1

  printf '\n'
  printf '  %s\n' "$_fb_title"
  if [ -n "$_fb_subtitle" ]; then
    printf '  %s\n' "$_fb_subtitle"
  fi
  printf '  ---\n'

  for _fb_item do
    printf '%3d) %s\n' "$_fb_i" "$_fb_item"
    _fb_i=$((_fb_i + 1))
  done

  printf '\n'
  printf 'Enter number (or empty to cancel): '

  _fb_selection=''
  IFS= read -r _fb_selection </dev/tty 2>/dev/null || read -r _fb_selection

  if [ -z "$_fb_selection" ]; then
    unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
    return 1
  fi

  # Validate: must be a positive integer
  case "$_fb_selection" in
    *[!0-9]*)
      printf 'Invalid input: not a number\n'
      unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
      return 1
      ;;
    '')
      printf 'Invalid input: not a number\n'
      unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
      return 1
      ;;
  esac

  # Check for zero (0-based selection is internal, but input is 1-based)
  if [ "$_fb_selection" -eq 0 ]; then
    printf 'Invalid selection\n'
    unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
    return 1
  fi

  # Check range
  if [ "$_fb_selection" -gt "$_fb_count" ]; then
    printf 'Invalid selection\n'
    unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection
    return 1
  fi

  # Convert to 0-based index
  _fb_idx=$((_fb_selection - 1))
  printf '%d' "$_fb_idx"
  TUI_RESULT="$_fb_idx"
  unset _fb_title _fb_subtitle _fb_count _fb_i _fb_item _fb_selection _fb_idx
  return 0
}
