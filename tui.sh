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
