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
  clear_screen
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
TUI_KEY_CTRL_D="ctrl_d"
TUI_KEY_DELETE="delete"
TUI_KEY_ASTERISK="asterisk"
TUI_KEY_MINUS="minus"
TUI_KEY_Q="q"
TUI_KEY_HELP="help"
TUI_KEY_NUMBER="number"
TUI_KEY_UNKNOWN="unknown"

# ---------------------------------------------------------------------------
# Section 8: Shell-aware key reading
# ---------------------------------------------------------------------------

# Read a single raw byte from /dev/tty into _tui_rb_byte.
# Uses read -rsn1 on bash/zsh (no process spawn), dd on POSIX shells.
# Returns 0 on success, 1 on failure (EOF).
# IMPORTANT: Caller must NOT wrap in $() — use _tui_rb_byte directly.
_tui_read_byte() {
  _tui_rb_byte=''
  if [ "$_tui_has_read_n" = "true" ]; then
    # shellcheck disable=SC3045
    IFS= read -rsn1 _tui_rb_byte 2>/dev/null </dev/tty || true
  else
    _tui_rb_byte=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
  fi
  [ -n "$_tui_rb_byte" ]
}

# High-level key reader with escape sequence parsing.
# Sets _tui_rk_result to the symbolic key name.
# Sets _tui_rk_digit when result is TUI_KEY_NUMBER.
# IMPORTANT: Caller must NOT wrap in $() — use _tui_rk_result directly.
# shellcheck disable=SC2034
_tui_read_key() {
  _tui_read_byte || { _tui_rk_result="$TUI_KEY_UNKNOWN"; return; }

  _tui_rk_nl='
'
  _tui_rk_cr=$(printf '\r')
  _tui_rk_esc=$(printf '\033')
  _tui_rk_tab=$(printf '\t')
  _tui_rk_bs=$(printf '\010')
  _tui_rk_del=$(printf '\177')

  case "$_tui_rb_byte" in
    "$_tui_rk_nl"|"$_tui_rk_cr")
      _tui_rk_result="$TUI_KEY_ENTER"
      ;;
    ' ')
      _tui_rk_result="$TUI_KEY_SPACE"
      ;;
    "$(printf '\004')")
      _tui_rk_result="$TUI_KEY_CTRL_D"
      ;;
    '*')
      _tui_rk_result="$TUI_KEY_ASTERISK"
      ;;
    '-')
      _tui_rk_result="$TUI_KEY_MINUS"
      ;;
    "$_tui_rk_tab")
      _tui_rk_result="$TUI_KEY_TAB"
      ;;
    "$_tui_rk_del"|"$_tui_rk_bs")
      _tui_rk_result="$TUI_KEY_BACKSPACE"
      ;;
    'q'|'Q')
      _tui_rk_result="$TUI_KEY_Q"
      ;;
    '?')
      _tui_rk_result="$TUI_KEY_HELP"
      ;;
    'j')
      _tui_rk_result="$TUI_KEY_UP"
      ;;
    'k')
      _tui_rk_result="$TUI_KEY_DOWN"
      ;;
    'G')
      _tui_rk_result="$TUI_KEY_END"
      ;;
    'g')
      _tui_rk_result="$TUI_KEY_HOME"
      ;;
    [0-9])
      _tui_rk_digit="$_tui_rb_byte"
      _tui_rk_result="$TUI_KEY_NUMBER"
      ;;
    "$_tui_rk_esc")
      _tui_key_timeout=${TUI_KEY_TIMEOUT:-10}
      stty min 0 time "$_tui_key_timeout" 2>/dev/null || true

      _tui_read_byte || _tui_rb_byte=''
      _tui_rk_c1="$_tui_rb_byte"

      if [ -z "$_tui_rk_c1" ]; then
        stty min 1 time 0 2>/dev/null || true
        _tui_rk_result="$TUI_KEY_ESC"
        unset _tui_key_timeout _tui_rk_c1
        return
      fi

      if [ "$_tui_rk_c1" = '[' ] || [ "$_tui_rk_c1" = 'O' ]; then
        _tui_read_byte || _tui_rb_byte=''
        _tui_rk_c2="$_tui_rb_byte"

        if [ -z "$_tui_rk_c2" ]; then
          stty min 1 time 0 2>/dev/null || true
          _tui_rk_result="$TUI_KEY_UNKNOWN"
          unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
          return
        fi

        case "$_tui_rk_c2" in
          A) _tui_rk_result="$TUI_KEY_UP" ;;
          B) _tui_rk_result="$TUI_KEY_DOWN" ;;
          C) _tui_rk_result="$TUI_KEY_RIGHT" ;;
          D) _tui_rk_result="$TUI_KEY_LEFT" ;;
          H) _tui_rk_result="$TUI_KEY_HOME" ;;
          F) _tui_rk_result="$TUI_KEY_END" ;;
          1|4|5|6)
            _tui_read_byte || _tui_rb_byte=''
            _tui_rk_c3="$_tui_rb_byte"
            stty min 1 time 0 2>/dev/null || true
            if [ "$_tui_rk_c3" = '~' ]; then
              case "$_tui_rk_c2" in
                5) _tui_rk_result="$TUI_KEY_PGUP" ;;
                6) _tui_rk_result="$TUI_KEY_PGDN" ;;
                1) _tui_rk_result="$TUI_KEY_HOME" ;;
                4) _tui_rk_result="$TUI_KEY_END" ;;
                *) _tui_rk_result="$TUI_KEY_UNKNOWN" ;;
              esac
            else
              _tui_rk_result="$TUI_KEY_UNKNOWN"
            fi
            unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2 _tui_rk_c3
            return
            ;;
          3)
            _tui_read_byte || _tui_rb_byte=''
            _tui_rk_c3="$_tui_rb_byte"
            stty min 1 time 0 2>/dev/null || true
            if [ "$_tui_rk_c3" = '~' ]; then
              _tui_rk_result="$TUI_KEY_DELETE"
            else
              _tui_rk_result="$TUI_KEY_UNKNOWN"
            fi
            unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2 _tui_rk_c3
            return
            ;;
        esac
        stty min 1 time 0 2>/dev/null || true
        unset _tui_key_timeout _tui_rk_c1 _tui_rk_c2
        return
      fi

      stty min 1 time 0 2>/dev/null || true
      _tui_rk_result="$TUI_KEY_UNKNOWN"
      unset _tui_key_timeout _tui_rk_c1
      return
      ;;
    *)
      _tui_rk_result="$TUI_KEY_UNKNOWN"
      ;;
  esac
  unset _tui_rk_nl _tui_rk_cr _tui_rk_esc _tui_rk_tab _tui_rk_bs _tui_rk_del
}

# ---------------------------------------------------------------------------
# Section 8a: Character reader for text input widgets
# ---------------------------------------------------------------------------

# Read a single character byte and return it directly (not symbolic).
# Used by text input widgets that need the actual character value.
# Sets _tui_rc_char to the byte, returns 0 on success, 1 on EOF.
# IMPORTANT: Caller must NOT wrap in $() — use _tui_rc_char directly.
_tui_read_char() {
  _tui_rc_char=''
  _tui_read_byte || return 1
  _tui_rc_char="$_tui_rb_byte"
  return 0
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

  _fb_selection=$(printf '%s' "$_fb_selection" | awk '{print $1 + 0}')

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
# Section 9a: Checklist fallback prompt
# ---------------------------------------------------------------------------

# _tui_checklist_fallback
# Uses _tc_* globals set by tui_checklist() for items and checked state.
# Prints newline-separated 0-based indexes to stdout.
# Sets TUI_RESULT to count of selected items.
# Returns 0 on selection, 1 on cancel/invalid.
_tui_checklist_fallback() {
  printf '\n'
  printf '  %s\n' "$_tc_title"
  if [ -n "$_tc_subtitle" ]; then
    printf '  %s\n' "$_tc_subtitle"
  fi
  printf '  ---\n'

  _fbc_i=1
  while [ "$_fbc_i" -le "$_tc_count" ]; do
    # shellcheck disable=SC2086
    eval "_fbc_label=\$_tc_label_$_fbc_i"
    # shellcheck disable=SC2086
    eval "_fbc_checked=\$_tc_checked_$_fbc_i"
    # shellcheck disable=SC2154
    if [ "$_fbc_checked" -eq 1 ]; then
      # shellcheck disable=SC2154
      printf '%3d) [x] %s\n' "$_fbc_i" "$_fbc_label"
    else
      # shellcheck disable=SC2154
      printf '%3d) [ ] %s\n' "$_fbc_i" "$_fbc_label"
    fi
    _fbc_i=$((_fbc_i + 1))
  done

  printf '\n'
  printf 'Enter numbers separated by spaces (or empty to cancel): '

  _fbc_selection=''
  IFS= read -r _fbc_selection </dev/tty 2>/dev/null || read -r _fbc_selection

  if [ -z "$_fbc_selection" ]; then
    unset _fbc_i _fbc_label _fbc_checked _fbc_selection
    return 1
  fi

  _fbc_count=0
  for _fbc_num in $_fbc_selection; do
    case "$_fbc_num" in
      *[!0-9]*) continue ;;
      '') continue ;;
    esac
    _fbc_num=$((_fbc_num + 0))
    if [ "$_fbc_num" -ge 1 ] && [ "$_fbc_num" -le "$_tc_count" ]; then
      _fbc_idx=$((_fbc_num - 1))
      printf '%d\n' "$_fbc_idx"
      _fbc_count=$((_fbc_count + 1))
    fi
  done

  if [ "$_fbc_count" -eq 0 ]; then
    printf 'No valid selections\n'
    unset _fbc_i _fbc_label _fbc_checked _fbc_selection _fbc_num _fbc_idx _fbc_count
    return 1
  fi

  TUI_RESULT=$_fbc_count
  unset _fbc_i _fbc_label _fbc_checked _fbc_selection _fbc_num _fbc_idx _fbc_count
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
# Section 11a: Rendering function for tui_checklist
# ---------------------------------------------------------------------------

# shellcheck disable=SC2034,SC2154
_tui_render_checklist() {
  clear_screen
  _rsc_rows=$(tput lines 2>/dev/null || printf '24')
  _rsc_cols=$(tput cols 2>/dev/null || printf '80')
  _rsc_box_w=$((_rsc_cols - 4))
  [ "$_rsc_box_w" -lt 40 ] && _rsc_box_w=40
  _rsc_inner=$((_rsc_box_w - 2))
  _rsc_x=2
  _rsc_r=1

  move_cursor "$_rsc_r" "$_rsc_x"
  printf '%s' "$TUI_BOX_TL"
  _rsc_i=1; while [ "$_rsc_i" -le "$_rsc_inner" ]; do printf '%s' "$TUI_BOX_H"; _rsc_i=$((_rsc_i + 1)); done
  printf '%s' "$TUI_BOX_TR"
  _rsc_r=$((_rsc_r + 1))

  move_cursor "$_rsc_r" "$_rsc_x"
  printf '%s' "$TUI_BOX_V"
  _rsc_tlen=${#_tc_title}
  if [ "$_rsc_tlen" -gt "$_rsc_inner" ]; then _rsc_tlen=$_rsc_inner; fi
  _rsc_tshow=$(printf '%s' "$_tc_title" | awk -v L="$_rsc_tlen" '{print substr($0,1,L)}')
  _rsc_pad=$((_rsc_inner - ${#_rsc_tshow}))
  _rsc_pl=$((_rsc_pad / 2)); _rsc_pr=$((_rsc_pad - _rsc_pl))
  _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_pl" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
  printf '%s%s%s' "$TUI_BOLD" "$_rsc_tshow" "$TUI_RESET"
  _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_pr" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rsc_r=$((_rsc_r + 1))

  if [ -n "$_tc_subtitle" ]; then
    move_cursor "$_rsc_r" "$_rsc_x"
    printf '%s' "$TUI_BOX_V"
    _rsc_slen=${#_tc_subtitle}
    if [ "$_rsc_slen" -gt "$_rsc_inner" ]; then _rsc_slen=$_rsc_inner; fi
    _rsc_sshow=$(printf '%s' "$_tc_subtitle" | awk -v L="$_rsc_slen" '{print substr($0,1,L)}')
    _rsc_spad=$((_rsc_inner - ${#_rsc_sshow}))
    _rsc_spl=$((_rsc_spad / 2)); _rsc_spr=$((_rsc_spad - _rsc_spl))
    _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_spl" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
    printf '%s%s%s' "$TUI_DIM" "$_rsc_sshow" "$TUI_RESET"
    _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_spr" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rsc_r=$((_rsc_r + 1))
  fi

  move_cursor "$_rsc_r" "$_rsc_x"
  printf '%s' "$TUI_BOX_V"
  _rsc_i=1; while [ "$_rsc_i" -le "$_rsc_inner" ]; do printf '%s' "$TUI_BOX_H"; _rsc_i=$((_rsc_i + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rsc_r=$((_rsc_r + 1))

  _rsc_status_row=$((_rsc_rows - 3))
  _rsc_bottom_row=$((_rsc_rows - 2))
  _rsc_footer_row=$((_rsc_rows - 1))
  _tc_page_size=$((_rsc_status_row - _rsc_r + 1))
  [ "$_tc_page_size" -lt 1 ] && _tc_page_size=1

  if [ "$_tc_scroll" -gt 1 ]; then
    move_cursor "$_rsc_r" $((_rsc_x + _rsc_box_w - 9))
    printf '%s%smore%s' "$TUI_DIM" '↑' "$TUI_RESET"
  fi

  _rsc_end=$((_tc_scroll + _tc_page_size - 1))
  [ "$_rsc_end" -gt "$_tc_count" ] && _rsc_end=$_tc_count
  _rsc_maxlab=$((_rsc_inner - 9))
  [ "$_rsc_maxlab" -lt 3 ] && _rsc_maxlab=3
  _rsc_i=$_tc_scroll
  while [ "$_rsc_i" -le "$_rsc_end" ]; do
    # shellcheck disable=SC2086
    eval "_rsc_lab=\$_tc_label_$_rsc_i"
    # shellcheck disable=SC2086
    eval "_rsc_checked=\$_tc_checked_$_rsc_i"
    # shellcheck disable=SC2154
    _rsc_trunc=$(printf '%s' "$_rsc_lab" | awk -v L="$_rsc_maxlab" '{print substr($0,1,L)}')
    move_cursor "$_rsc_r" "$_rsc_x"
    printf '%s' "$TUI_BOX_V"
    if [ "$_rsc_i" -eq "$_tc_cursor" ]; then
      if [ "$_rsc_checked" -eq 1 ]; then
        printf '%s[x] %3d) %s' "$TUI_REV" "$_rsc_i" "$_rsc_trunc"
      else
        printf '%s[ ] %3d) %s' "$TUI_REV" "$_rsc_i" "$_rsc_trunc"
      fi
      _rsc_used=$((9 + ${#_rsc_trunc}))
      _rsc_fill=$((_rsc_inner - _rsc_used))
      [ "$_rsc_fill" -gt 0 ] && _rsc_j=0 && while [ "$_rsc_j" -lt "$_rsc_fill" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
      printf '%s' "$TUI_RESET"
    else
      if [ "$_rsc_checked" -eq 1 ]; then
        printf '[x] %3d) %s' "$_rsc_i" "$_rsc_trunc"
      else
        printf '[ ] %3d) %s' "$_rsc_i" "$_rsc_trunc"
      fi
      _rsc_used=$((9 + ${#_rsc_trunc}))
      _rsc_fill=$((_rsc_inner - _rsc_used))
      [ "$_rsc_fill" -gt 0 ] && _rsc_j=0 && while [ "$_rsc_j" -lt "$_rsc_fill" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
    fi
    printf '%s' "$TUI_BOX_V"
    _rsc_r=$((_rsc_r + 1))
    _rsc_i=$((_rsc_i + 1))
  done

  while [ "$_rsc_r" -le "$_rsc_status_row" ]; do
    move_cursor "$_rsc_r" "$_rsc_x"
    printf '%s' "$TUI_BOX_V"
    _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_inner" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rsc_r=$((_rsc_r + 1))
  done

  if [ "$_rsc_end" -lt "$_tc_count" ]; then
    _rsc_drow=$((_rsc_r - 1))
    move_cursor "$_rsc_drow" $((_rsc_x + _rsc_box_w - 9))
    printf '%s%smore%s' "$TUI_DIM" '↓' "$TUI_RESET"
  fi

  move_cursor "$_rsc_status_row" "$_rsc_x"
  printf '%s' "$TUI_BOX_V"
  _rsc_j=0; while [ "$_rsc_j" -lt "$_rsc_inner" ]; do printf ' '; _rsc_j=$((_rsc_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  move_cursor "$_rsc_status_row" $((_rsc_x + 2))
  if [ -n "$_tc_error_msg" ]; then
    printf '%s%s%s' "$TUI_RED" "$_tc_error_msg" "$TUI_RESET"
  else
    printf '%d of %d selected' "$_tc_selected" "$_tc_count"
  fi

  move_cursor "$_rsc_bottom_row" "$_rsc_x"
  printf '%s' "$TUI_BOX_BL"
  _rsc_i=1; while [ "$_rsc_i" -le "$_rsc_inner" ]; do printf '%s' "$TUI_BOX_H"; _rsc_i=$((_rsc_i + 1)); done
  printf '%s' "$TUI_BOX_BR"

  move_cursor "$_rsc_footer_row" "$_rsc_x"
  if [ "$_tc_show_help" = "true" ]; then
    _rsc_ft='Space=toggle  Ctrl+D=Done  Esc=Cancel  *=SelectAll  -=DeselectAll  Up/Dn Move  PgUp/PgDn Page  Home/End  j/k Vi  ? Less'
  else
    _rsc_ft='Space=toggle  Ctrl+D=Done  Esc=Cancel  ?=More'
  fi
  printf '%s%s%s' "$TUI_DIM" "$_rsc_ft" "$TUI_RESET"

  printf '%s[?25l' "$ESC"

  unset _rsc_rows _rsc_cols _rsc_box_w _rsc_inner _rsc_x _rsc_r _rsc_i _rsc_j
  unset _rsc_tlen _rsc_tshow _rsc_pad _rsc_pl _rsc_pr _rsc_slen _rsc_sshow _rsc_spad _rsc_spl _rsc_spr
  unset _rsc_status_row _rsc_bottom_row _rsc_footer_row _rsc_end _rsc_maxlab _rsc_lab _rsc_trunc
  unset _rsc_checked _rsc_used _rsc_fill _rsc_drow _rsc_ft
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

  if [ "$_ts_count" -eq 0 ]; then
    return 1
  fi

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

  while :; do
    _tui_render_select
    # shellcheck disable=SC2034
    _tui_read_key
    key="$_tui_rk_result"

    if [ "$key" != "$TUI_KEY_NUMBER" ] && [ -n "$_ts_go_digits" ]; then
      _ts_target=$(printf '%s' "$_ts_go_digits" | awk '{print $1 + 0}')
      if [ "$_ts_target" -ge 1 ] && [ "$_ts_target" -le "$_ts_count" ]; then
        _ts_cursor=$_ts_target
        _ts_scroll=$((_ts_target - _ts_page_size / 2))
        [ "$_ts_scroll" -lt 1 ] && _ts_scroll=1
        _ts_max_scroll=$((_ts_count - _ts_page_size + 1))
        [ "$_ts_max_scroll" -lt 1 ] && _ts_max_scroll=1
        [ "$_ts_scroll" -gt "$_ts_max_scroll" ] && _ts_scroll=$_ts_max_scroll
      else
        _ts_error_msg="Item $_ts_target not found"
      fi
      _ts_go_digits=''
    fi

    case "$key" in
      "$TUI_KEY_UP")
        if [ "$_ts_cursor" -gt 1 ]; then
          _ts_cursor=$((_ts_cursor - 1))
          if [ "$_ts_cursor" -lt "$_ts_scroll" ]; then
            _ts_scroll=$((_ts_scroll - 1))
          fi
        fi
        _ts_error_msg=''
        ;;
      "$TUI_KEY_DOWN")
        if [ "$_ts_cursor" -lt "$_ts_count" ]; then
          _ts_cursor=$((_ts_cursor + 1))
          _ts_bottom=$((_ts_scroll + _ts_page_size - 1))
          if [ "$_ts_cursor" -gt "$_ts_bottom" ]; then
            _ts_scroll=$((_ts_scroll + 1))
          fi
        fi
        _ts_error_msg=''
        ;;
      "$TUI_KEY_PGUP")
        _ts_scroll=$((_ts_scroll - _ts_page_size))
        [ "$_ts_scroll" -lt 1 ] && _ts_scroll=1
        _ts_cursor=$_ts_scroll
        _ts_error_msg=''
        ;;
      "$TUI_KEY_PGDN")
        _ts_scroll=$((_ts_scroll + _ts_page_size))
        _ts_max_scroll=$((_ts_count - _ts_page_size + 1))
        [ "$_ts_max_scroll" -lt 1 ] && _ts_max_scroll=1
        [ "$_ts_scroll" -gt "$_ts_max_scroll" ] && _ts_scroll=$_ts_max_scroll
        _ts_bottom=$((_ts_scroll + _ts_page_size - 1))
        [ "$_ts_bottom" -gt "$_ts_count" ] && _ts_bottom=$_ts_count
        _ts_cursor=$_ts_bottom
        _ts_error_msg=''
        ;;
      "$TUI_KEY_HOME")
        _ts_cursor=1; _ts_scroll=1; _ts_error_msg=''
        ;;
      "$TUI_KEY_END")
        _ts_cursor=$_ts_count
        _ts_max_scroll=$((_ts_count - _ts_page_size + 1))
        [ "$_ts_max_scroll" -lt 1 ] && _ts_max_scroll=1
        _ts_scroll=$_ts_max_scroll
        _ts_error_msg=''
        ;;
      "$TUI_KEY_ENTER")
        tui_restore
        _ts_idx=$((_ts_cursor - 1))
        TUI_RESULT=$_ts_idx
        printf '%d\n' "$_ts_idx"
        unset _ts_idx _ts_max_scroll _ts_bottom _ts_target _ts_go_digits _ts_error_msg
        return 0
        ;;
      "$TUI_KEY_ESC"|"$TUI_KEY_Q")
        tui_restore
        TUI_RESULT=''
        unset _ts_max_scroll _ts_bottom _ts_target _ts_go_digits _ts_error_msg
        return 1
        ;;
      "$TUI_KEY_HELP")
        if [ "$_ts_show_help" = "true" ]; then
          _ts_show_help=false
        else
          _ts_show_help=true
        fi
        ;;
      "$TUI_KEY_NUMBER")
        _ts_go_digits="${_ts_go_digits}${_tui_rk_digit}"
        _ts_error_msg=''
        _ts_target=$(printf '%s' "$_ts_go_digits" | awk '{print $1 + 0}')
        if [ "$_ts_target" -ge 1 ] && [ "$_ts_target" -le "$_ts_count" ]; then
          _ts_next=$((_ts_target * 10))
          if [ "$_ts_next" -gt "$_ts_count" ]; then
            _ts_cursor=$_ts_target
            _ts_scroll=$((_ts_target - _ts_page_size / 2))
            [ "$_ts_scroll" -lt 1 ] && _ts_scroll=1
            _ts_max_scroll=$((_ts_count - _ts_page_size + 1))
            [ "$_ts_max_scroll" -lt 1 ] && _ts_max_scroll=1
            [ "$_ts_scroll" -gt "$_ts_max_scroll" ] && _ts_scroll=$_ts_max_scroll
            _ts_go_digits=''
          fi
        elif [ "$_ts_target" -gt "$_ts_count" ]; then
          _ts_error_msg="Item $_ts_target not found"
          _ts_go_digits=''
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Section 12a: tui_checklist() — Multi-select checkbox widget
# ---------------------------------------------------------------------------

# tui_checklist title subtitle item1 item2 ... [--checked N1 N2 ...]
# Multi-select checklist with [x]/[ ] checkboxes.
# SPACE toggles items. Ctrl+D/Enter confirms. Esc/q cancels.
# * = Select All, - = Deselect All
# Prints newline-separated 0-based indexes of checked items to stdout.
# Sets TUI_RESULT to count of selected items.
# Returns 0 on success, 1 on cancel.
tui_checklist() {
  _tc_title=$1; _tc_subtitle=$2; shift 2

  _tc_count=0
  _tc_selected=0
  _tc_parse_mode=items

  for _tc_arg in "$@"; do
    if [ "$_tc_arg" = "--checked" ]; then
      _tc_parse_mode=checked; continue
    fi
    if [ "$_tc_parse_mode" = "items" ]; then
      _tc_count=$((_tc_count + 1))
      _tc_safe=$(printf '%s' "$_tc_arg" | sed "s/'/'\\\\''/g")
      eval "_tc_label_$_tc_count='$_tc_safe'"
      eval "_tc_checked_$_tc_count=0"
    else
      _tc_ci=$((_tc_arg + 1))
      if [ "$_tc_ci" -ge 1 ] && [ "$_tc_ci" -le "$_tc_count" ]; then
        eval "_tc_checked_$_tc_ci=1"
        _tc_selected=$((_tc_selected + 1))
      fi
    fi
  done
  unset _tc_arg _tc_safe _tc_ci _tc_parse_mode

  if [ "$_tc_count" -eq 0 ]; then
    return 1
  fi

  _tc_cursor=1
  _tc_scroll=1
  _tc_show_help=false
  _tc_error_msg=''
  _tc_page_size=1

  if [ "$_tui_use_tui" = "false" ]; then
    _tui_checklist_fallback
    _tc_rc=$?
    _tc_i=1
    while [ "$_tc_i" -le "$_tc_count" ]; do
      # shellcheck disable=SC2086
      eval "unset _tc_label_$_tc_i"
      # shellcheck disable=SC2086
      eval "unset _tc_checked_$_tc_i"
      _tc_i=$((_tc_i + 1))
    done
    _tc_ret=$_tc_rc
    unset _tc_title _tc_subtitle _tc_count _tc_selected _tc_cursor _tc_scroll
    unset _tc_show_help _tc_error_msg _tc_page_size _tc_i _tc_rc
    # shellcheck disable=SC2086
    return $_tc_ret
  fi

  tui_init

  while :; do
    _tui_render_checklist
    # shellcheck disable=SC2034
    _tui_read_key
    key="$_tui_rk_result"

    case "$key" in
      "$TUI_KEY_SPACE")
        # shellcheck disable=SC2086
        eval "_tc_cur=\$_tc_checked_$_tc_cursor"
        # shellcheck disable=SC2154
        if [ "$_tc_cur" -eq 1 ]; then
          # shellcheck disable=SC2086
          eval "_tc_checked_$_tc_cursor=0"
          _tc_selected=$((_tc_selected - 1))
        else
          # shellcheck disable=SC2086
          eval "_tc_checked_$_tc_cursor=1"
          _tc_selected=$((_tc_selected + 1))
        fi
        _tc_error_msg=''
        ;;
      "$TUI_KEY_CTRL_D"|"$TUI_KEY_ENTER")
        if [ "$_tc_selected" -eq 0 ]; then
          _tc_error_msg="Select at least one item"
        else
          tui_restore
          _tc_i=1
          while [ "$_tc_i" -le "$_tc_count" ]; do
            # shellcheck disable=SC2086
            eval "_tc_chk=\$_tc_checked_$_tc_i"
            # shellcheck disable=SC2154
            if [ "$_tc_chk" -eq 1 ]; then
              _tc_idx=$((_tc_i - 1))
              printf '%d\n' "$_tc_idx"
            fi
            _tc_i=$((_tc_i + 1))
          done
          TUI_RESULT=$_tc_selected
          _tc_i=1
          while [ "$_tc_i" -le "$_tc_count" ]; do
            # shellcheck disable=SC2086
            eval "unset _tc_label_$_tc_i"
            # shellcheck disable=SC2086
            eval "unset _tc_checked_$_tc_i"
            _tc_i=$((_tc_i + 1))
          done
          unset _tc_i _tc_chk _tc_idx _tc_cur _tc_title _tc_subtitle _tc_count
          unset _tc_selected _tc_cursor _tc_scroll _tc_show_help _tc_error_msg _tc_page_size
          return 0
        fi
        ;;
      "$TUI_KEY_ASTERISK")
        _tc_i=1
        while [ "$_tc_i" -le "$_tc_count" ]; do
          # shellcheck disable=SC2086
          eval "_tc_checked_$_tc_i=1"
          _tc_i=$((_tc_i + 1))
        done
        _tc_selected=$_tc_count
        _tc_error_msg=''
        ;;
      "$TUI_KEY_MINUS")
        _tc_i=1
        while [ "$_tc_i" -le "$_tc_count" ]; do
          # shellcheck disable=SC2086
          eval "_tc_checked_$_tc_i=0"
          _tc_i=$((_tc_i + 1))
        done
        _tc_selected=0
        _tc_error_msg=''
        ;;
      "$TUI_KEY_UP")
        if [ "$_tc_cursor" -gt 1 ]; then
          _tc_cursor=$((_tc_cursor - 1))
          if [ "$_tc_cursor" -lt "$_tc_scroll" ]; then
            _tc_scroll=$((_tc_scroll - 1))
          fi
        fi
        _tc_error_msg=''
        ;;
      "$TUI_KEY_DOWN")
        if [ "$_tc_cursor" -lt "$_tc_count" ]; then
          _tc_cursor=$((_tc_cursor + 1))
          _tc_bottom=$((_tc_scroll + _tc_page_size - 1))
          if [ "$_tc_cursor" -gt "$_tc_bottom" ]; then
            _tc_scroll=$((_tc_scroll + 1))
          fi
        fi
        _tc_error_msg=''
        ;;
      "$TUI_KEY_PGUP")
        _tc_scroll=$((_tc_scroll - _tc_page_size))
        [ "$_tc_scroll" -lt 1 ] && _tc_scroll=1
        _tc_cursor=$_tc_scroll
        _tc_error_msg=''
        ;;
      "$TUI_KEY_PGDN")
        _tc_scroll=$((_tc_scroll + _tc_page_size))
        _tc_max_scroll=$((_tc_count - _tc_page_size + 1))
        [ "$_tc_max_scroll" -lt 1 ] && _tc_max_scroll=1
        [ "$_tc_scroll" -gt "$_tc_max_scroll" ] && _tc_scroll=$_tc_max_scroll
        _tc_bottom=$((_tc_scroll + _tc_page_size - 1))
        [ "$_tc_bottom" -gt "$_tc_count" ] && _tc_bottom=$_tc_count
        _tc_cursor=$_tc_bottom
        _tc_error_msg=''
        ;;
      "$TUI_KEY_HOME")
        _tc_cursor=1; _tc_scroll=1; _tc_error_msg=''
        ;;
      "$TUI_KEY_END")
        _tc_cursor=$_tc_count
        _tc_max_scroll=$((_tc_count - _tc_page_size + 1))
        [ "$_tc_max_scroll" -lt 1 ] && _tc_max_scroll=1
        _tc_scroll=$_tc_max_scroll
        _tc_error_msg=''
        ;;
      "$TUI_KEY_ESC"|"$TUI_KEY_Q")
        tui_restore
        TUI_RESULT=''
        _tc_i=1
        while [ "$_tc_i" -le "$_tc_count" ]; do
          # shellcheck disable=SC2086
          eval "unset _tc_label_$_tc_i"
          # shellcheck disable=SC2086
          eval "unset _tc_checked_$_tc_i"
          _tc_i=$((_tc_i + 1))
        done
        unset _tc_i _tc_cur _tc_title _tc_subtitle _tc_count _tc_selected _tc_cursor
        unset _tc_scroll _tc_show_help _tc_error_msg _tc_page_size _tc_bottom _tc_max_scroll
        return 1
        ;;
      "$TUI_KEY_HELP")
        if [ "$_tc_show_help" = "true" ]; then
          _tc_show_help=false
        else
          _tc_show_help=true
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Demo / standalone execution (only when run directly, not sourced)
# ---------------------------------------------------------------------------

case "${0##*/}" in
  tui.sh)
    if [ "${1:-}" = "--demo" ]; then
      shift
      if [ $# -eq 0 ]; then
        set -- "Core utilities" "Network tools" "Development tools" \
               "Documentation" "Extra packages" "Security tools" \
               "System monitoring" "Database clients" "Cloud CLI tools" \
               "Container tools" "Version control" "Build tools" \
               "Text editors" "Terminal utilities" "File managers" \
               "Media codecs" "Graphics tools" "Office suite" \
               "Virtualization" "Backup utilities" "DNS tools" \
               "VPN clients" "SSH tools" "Python packages" "Node.js global"
      fi
      tui_select "TUI Engine Demo" "Select an item to test the widget:" "$@"
      _demo_rc=$?
      if [ $_demo_rc -eq 0 ]; then
        printf 'Selected index: %s (TUI_RESULT=%s)\n' "$TUI_RESULT" "$TUI_RESULT"
      else
        printf 'Cancelled\n'
      fi
      exit $_demo_rc
    fi
    if [ "${1:-}" = "--demo-checklist" ]; then
      shift
      if [ $# -eq 0 ]; then
        set -- "Core utilities" "Network tools" "Development tools" \
               "Documentation" "Extra packages" "Security tools"
      fi
      tui_checklist "Checklist Demo" "Space=toggle, Ctrl+D=Done, *=All, -=None" \
        "$@" --checked 0 2
      _demo_rc=$?
      if [ $_demo_rc -eq 0 ]; then
        printf 'Selected indexes:\n%s\n' "$(cat)"
      else
        printf 'Cancelled\n'
      fi
      exit $_demo_rc
    fi
    if [ $# -gt 0 ]; then
      tui_select "$@"
      exit $?
    fi
    ;;
esac
