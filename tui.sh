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

# ---------------------------------------------------------------------------
# Section 10: Box drawing helper
# ---------------------------------------------------------------------------

_tui_draw_box() {
  _db_x=$1; _db_y=$2; _db_w=$3; _db_h=$4; _db_title=$5
  _db_inner=$((_db_w - 2))
  _db_r=$_db_y

  move_cursor "$_db_r" "$_db_x"
  printf '%s' "$TUI_BOX_TL"
  _db_i=1; while [ "$_db_i" -le "$_db_inner" ]; do printf '%s' "$TUI_BOX_H"; _db_i=$((_db_i + 1)); done
  printf '%s' "$TUI_BOX_TR"
  _db_r=$((_db_r + 1))

  move_cursor "$_db_r" "$_db_x"
  printf '%s' "$TUI_BOX_V"
  if [ -n "$_db_title" ]; then
    _db_pad=$((_db_inner - ${#_db_title}))
    _db_pl=$((_db_pad / 2)); _db_pr=$((_db_pad - _db_pl))
    _db_j=0; while [ "$_db_j" -lt "$_db_pl" ]; do printf ' '; _db_j=$((_db_j + 1)); done
    printf '%s%s%s' "$TUI_BOLD" "$_db_title" "$TUI_RESET"
    _db_j=0; while [ "$_db_j" -lt "$_db_pr" ]; do printf ' '; _db_j=$((_db_j + 1)); done
  else
    _db_j=0; while [ "$_db_j" -lt "$_db_inner" ]; do printf ' '; _db_j=$((_db_j + 1)); done
  fi
  printf '%s' "$TUI_BOX_V"
  _db_r=$((_db_r + 1))

  move_cursor "$_db_r" "$_db_x"
  printf '%s' "$TUI_BOX_V"
  _db_i=1; while [ "$_db_i" -le "$_db_inner" ]; do printf '%s' "$TUI_BOX_H"; _db_i=$((_db_i + 1)); done
  printf '%s' "$TUI_BOX_V"
  _db_r=$((_db_r + 1))

  _db_body=$((_db_h - 4))
  _db_b=1
  while [ "$_db_b" -le "$_db_body" ]; do
    move_cursor "$_db_r" "$_db_x"
    printf '%s' "$TUI_BOX_V"
    _db_j=0; while [ "$_db_j" -lt "$_db_inner" ]; do printf ' '; _db_j=$((_db_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _db_r=$((_db_r + 1))
    _db_b=$((_db_b + 1))
  done

  move_cursor "$_db_r" "$_db_x"
  printf '%s' "$TUI_BOX_BL"
  _db_i=1; while [ "$_db_i" -le "$_db_inner" ]; do printf '%s' "$TUI_BOX_H"; _db_i=$((_db_i + 1)); done
  printf '%s' "$TUI_BOX_BR"

  unset _db_x _db_y _db_w _db_h _db_title _db_inner _db_r _db_i _db_j _db_pad _db_pl _db_pr _db_body _db_b
}

# ---------------------------------------------------------------------------
# Section 11: Rendering function for tui_select
# ---------------------------------------------------------------------------

# shellcheck disable=SC2034
_tui_render_select() {
  clear_screen
  _rs_rows=$(tput lines 2>/dev/null || printf '24')
  _rs_cols=$(tput cols 2>/dev/null || printf '80')
  _rs_box_w=$((_rs_cols - 4))
  [ "$_rs_box_w" -lt 40 ] && _rs_box_w=40
  _rs_inner=$((_rs_box_w - 2))
  _rs_x=2
  _rs_r=1

  move_cursor "$_rs_r" "$_rs_x"
  printf '%s' "$TUI_BOX_TL"
  _rs_i=1; while [ "$_rs_i" -le "$_rs_inner" ]; do printf '%s' "$TUI_BOX_H"; _rs_i=$((_rs_i + 1)); done
  printf '%s' "$TUI_BOX_TR"
  _rs_r=$((_rs_r + 1))

  move_cursor "$_rs_r" "$_rs_x"
  printf '%s' "$TUI_BOX_V"
  _rs_tlen=${#_ts_title}
  if [ "$_rs_tlen" -gt "$_rs_inner" ]; then _rs_tlen=$_rs_inner; fi
  _rs_tshow=$(printf '%s' "$_ts_title" | awk -v L="$_rs_tlen" '{print substr($0,1,L)}')
  _rs_pad=$((_rs_inner - ${#_rs_tshow}))
  _rs_pl=$((_rs_pad / 2)); _rs_pr=$((_rs_pad - _rs_pl))
  _rs_j=0; while [ "$_rs_j" -lt "$_rs_pl" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
  printf '%s%s%s' "$TUI_BOLD" "$_rs_tshow" "$TUI_RESET"
  _rs_j=0; while [ "$_rs_j" -lt "$_rs_pr" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rs_r=$((_rs_r + 1))

  if [ -n "$_ts_subtitle" ]; then
    move_cursor "$_rs_r" "$_rs_x"
    printf '%s' "$TUI_BOX_V"
    _rs_slen=${#_ts_subtitle}
    if [ "$_rs_slen" -gt "$_rs_inner" ]; then _rs_slen=$_rs_inner; fi
    _rsshow=$(printf '%s' "$_ts_subtitle" | awk -v L="$_rs_slen" '{print substr($0,1,L)}')
    _rs_spad=$((_rs_inner - ${#_rsshow}))
    _rs_spl=$((_rs_spad / 2)); _rs_spr=$((_rs_spad - _rs_spl))
    _rs_j=0; while [ "$_rs_j" -lt "$_rs_spl" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
    printf '%s%s%s' "$TUI_DIM" "$_rsshow" "$TUI_RESET"
    _rs_j=0; while [ "$_rs_j" -lt "$_rs_spr" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rs_r=$((_rs_r + 1))
  fi

  move_cursor "$_rs_r" "$_rs_x"
  printf '%s' "$TUI_BOX_V"
  _rs_i=1; while [ "$_rs_i" -le "$_rs_inner" ]; do printf '%s' "$TUI_BOX_H"; _rs_i=$((_rs_i + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rs_r=$((_rs_r + 1))

  _rs_status_row=$((_rs_rows - 3))
  _rs_bottom_row=$((_rs_rows - 2))
  _rs_footer_row=$((_rs_rows - 1))
  _ts_page_size=$((_rs_status_row - _rs_r + 1))
  [ "$_ts_page_size" -lt 1 ] && _ts_page_size=1

  if [ "$_ts_scroll" -gt 1 ]; then
    move_cursor "$_rs_r" $((_rs_x + _rs_box_w - 9))
    printf '%s%smore%s' "$TUI_DIM" '↑' "$TUI_RESET"
  fi

  _rs_end=$((_ts_scroll + _ts_page_size - 1))
  [ "$_rs_end" -gt "$_ts_count" ] && _rs_end=$_ts_count
  _rs_maxlab=$((_rs_inner - 6))
  [ "$_rs_maxlab" -lt 5 ] && _rs_maxlab=5
  _rs_i=$_ts_scroll
  while [ "$_rs_i" -le "$_rs_end" ]; do
    # shellcheck disable=SC2086
    eval "_rs_lab=\$_ts_label_$_rs_i"
    # shellcheck disable=SC2154
    _rs_trunc=$(printf '%s' "$_rs_lab" | awk -v L="$_rs_maxlab" '{print substr($0,1,L)}')
    move_cursor "$_rs_r" "$_rs_x"
    printf '%s' "$TUI_BOX_V"
    if [ "$_rs_i" -eq "$_ts_cursor" ]; then
      printf '%s%3d) %s' "$TUI_REV" "$_rs_i" "$_rs_trunc"
      _rs_used=$((5 + ${#_rs_trunc}))
      _rs_fill=$((_rs_inner - _rs_used))
      [ "$_rs_fill" -gt 0 ] && _rs_j=0 && while [ "$_rs_j" -lt "$_rs_fill" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
      printf '%s' "$TUI_RESET"
    else
      printf '%3d) %s' "$_rs_i" "$_rs_trunc"
      _rs_used=$((5 + ${#_rs_trunc}))
      _rs_fill=$((_rs_inner - _rs_used))
      [ "$_rs_fill" -gt 0 ] && _rs_j=0 && while [ "$_rs_j" -lt "$_rs_fill" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
    fi
    printf '%s' "$TUI_BOX_V"
    _rs_r=$((_rs_r + 1))
    _rs_i=$((_rs_i + 1))
  done

  while [ "$_rs_r" -le "$_rs_status_row" ]; do
    move_cursor "$_rs_r" "$_rs_x"
    printf '%s' "$TUI_BOX_V"
    _rs_j=0; while [ "$_rs_j" -lt "$_rs_inner" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rs_r=$((_rs_r + 1))
  done

  if [ "$_rs_end" -lt "$_ts_count" ]; then
    _rs_drow=$((_rs_r - 1))
    move_cursor "$_rs_drow" $((_rs_x + _rs_box_w - 9))
    printf '%s%smore%s' "$TUI_DIM" '↓' "$TUI_RESET"
  fi

  move_cursor "$_rs_status_row" "$_rs_x"
  printf '%s' "$TUI_BOX_V"
  _rs_j=0; while [ "$_rs_j" -lt "$_rs_inner" ]; do printf ' '; _rs_j=$((_rs_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  move_cursor "$_rs_status_row" $((_rs_x + 2))
  if [ -n "$_ts_go_digits" ]; then
    printf '%sGo to: %s_%s' "$TUI_BOLD" "$_ts_go_digits" "$TUI_RESET"
  elif [ -n "$_ts_error_msg" ]; then
    printf '%s%s%s' "$TUI_RED" "$_ts_error_msg" "$TUI_RESET"
  else
    printf 'Item %d of %d' "$_ts_cursor" "$_ts_count"
  fi

  move_cursor "$_rs_bottom_row" "$_rs_x"
  printf '%s' "$TUI_BOX_BL"
  _rs_i=1; while [ "$_rs_i" -le "$_rs_inner" ]; do printf '%s' "$TUI_BOX_H"; _rs_i=$((_rs_i + 1)); done
  printf '%s' "$TUI_BOX_BR"

  move_cursor "$_rs_footer_row" "$_rs_x"
  if [ "$_ts_show_help" = "true" ]; then
    _rs_ft='Up/Dn Move  Enter Select  Esc/q Cancel  PgUp/PgDn Page  Home/End  j/k Vi  ? Help  0-9 Jump'
  else
    _rs_ft='Up/Dn Move  Enter Select  Esc Cancel  ? Keys'
  fi
  printf '%s%s%s' "$TUI_DIM" "$_rs_ft" "$TUI_RESET"

  printf '%s[?25l' "$ESC"

  unset _rs_rows _rs_cols _rs_box_w _rs_inner _rs_x _rs_r _rs_i _rs_j
  unset _rs_tlen _rs_tshow _rs_pad _rs_pl _rs_pr _rs_slen _rsshow _rs_spad _rs_spl _rs_spr
  unset _rs_status_row _rs_bottom_row _rs_footer_row _rs_end _rs_maxlab _rs_lab _rs_trunc
  unset _rs_used _rs_fill _rs_drow _rs_ft
}

# ---------------------------------------------------------------------------
# Section 12: tui_select() function
# ---------------------------------------------------------------------------

tui_select() {
  _ts_title=$1; _ts_subtitle=$2; shift 2

  _ts_count=0
  for _ts_arg in "$@"; do
    _ts_count=$((_ts_count + 1))
    _ts_safe=$(printf '%s' "$_ts_arg" | sed "s/'/'\\\\''/g")
    eval "_ts_label_$_ts_count='$_ts_safe'"
  done
  unset _ts_arg _ts_safe

  _ts_cursor=1
  _ts_scroll=1
  _ts_show_help=false
  _ts_go_digits=''
  _ts_error_msg=''
  _ts_page_size=1

  if [ "$_tui_use_tui" = "false" ]; then
    _tui_fallback_prompt "$_ts_title" "$_ts_subtitle" "$@"
    return $?
  fi

  tui_init

  # Main event loop — implemented in task 2
  tui_restore
  return 1
}
