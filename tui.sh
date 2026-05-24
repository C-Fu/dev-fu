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
  # Append sentinel char to prevent $() from stripping trailing newlines.
  # Critical: stty may fail silently, leaving terminal in cooked mode where
  # Enter sends \n (0x0A) — $() strips it, making the byte undetectable.
  _tui_rb_byte=$(dd bs=1 count=1 2>/dev/null </dev/tty; printf 'X')
  _tui_rb_byte="${_tui_rb_byte%X}"
  [ -n "$_tui_rb_byte" ]
}

# High-level key reader with escape sequence parsing.
# Sets _tui_rk_result to the symbolic key name.
# Sets _tui_rk_digit when result is TUI_KEY_NUMBER.
# IMPORTANT: Caller must NOT wrap in $() — use _tui_rk_result directly.
# shellcheck disable=SC2034
_tui_read_key() {
  _tui_rk_result="$TUI_KEY_UNKNOWN"
  _tui_read_byte || return
  _tui_rk_digit=''

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
      # Numeric byte comparison catches Enter/Esc/BS regardless of shell quirks
      _tui_rb_dec=$(printf '%s' "$_tui_rb_byte" | od -A n -t d1 2>/dev/null | awk '{print $1}')
      case "${_tui_rb_dec:-}" in
        10|13)  _tui_rk_result="$TUI_KEY_ENTER" ;;
        27)    _tui_rk_result="$TUI_KEY_ESC" ;;
        127|8) _tui_rk_result="$TUI_KEY_BACKSPACE" ;;
        9)     _tui_rk_result="$TUI_KEY_TAB" ;;
        32)    _tui_rk_result="$TUI_KEY_SPACE" ;;
        *)     _tui_rk_result="$TUI_KEY_UNKNOWN" ;;
      esac
      unset _tui_rb_dec
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
# Section 13: Radio glyph auto-detection
# ---------------------------------------------------------------------------

# Auto-detect radio glyphs based on locale (same heuristic as box-drawing)
_tui_radio_glyph_on=''
_tui_radio_glyph_off=''
_tui_radio_init_glyphs() {
  _locale="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
  case "$_locale" in
    *UTF-8*|*utf-8*|*utf8*|*UTF8*)
      _tui_radio_glyph_on='(•)'
      _tui_radio_glyph_off='(○)'
      ;;
    *)
      _tui_radio_glyph_on='(*)'
      _tui_radio_glyph_off='( )'
      ;;
  esac
  unset _locale
}
_tui_radio_init_glyphs

# ---------------------------------------------------------------------------
# Section 13a: Radio fallback prompt
# ---------------------------------------------------------------------------

# _tui_radio_fallback
# Uses _tr_* globals set by tui_radio() for items and selection state.
# Prints 0-based index to stdout, sets TUI_RESULT.
# Returns 0 on selection, 1 on cancel/invalid.
_tui_radio_fallback() {
  printf '\n'
  printf '  %s\n' "$_tr_title"
  if [ -n "$_tr_subtitle" ]; then
    printf '  %s\n' "$_tr_subtitle"
  fi
  printf '  ---\n'

  _fbr_i=1
  while [ "$_fbr_i" -le "$_tr_count" ]; do
    # shellcheck disable=SC2086
    eval "_fbr_lab=\$_tr_label_$_fbr_i"
    # shellcheck disable=SC2154
    if [ "$_fbr_i" = "$_tr_selected" ]; then
      printf '%3d) %s %s\n' "$_fbr_i" "$_tui_radio_glyph_on" "$_fbr_lab"
    else
      printf '%3d) %s %s\n' "$_fbr_i" "$_tui_radio_glyph_off" "$_fbr_lab"
    fi
    _fbr_i=$((_fbr_i + 1))
  done

  printf '\n'
  printf 'Enter number (empty to cancel): '
  _fbr_input=''
  IFS= read -r _fbr_input </dev/tty 2>/dev/null || read -r _fbr_input

  if [ -z "$_fbr_input" ]; then
    unset _fbr_i _fbr_lab _fbr_input
    return 1
  fi

  case "$_fbr_input" in
    *[!0-9]*) unset _fbr_i _fbr_lab _fbr_input; return 1 ;;
    '') unset _fbr_i _fbr_lab _fbr_input; return 1 ;;
  esac

  _fbr_input=$((_fbr_input + 0))
  if [ "$_fbr_input" -ge 1 ] && [ "$_fbr_input" -le "$_tr_count" ]; then
    _fbr_idx=$((_fbr_input - 1))
    printf '%d\n' "$_fbr_idx"
    TUI_RESULT="$_fbr_idx"
    unset _fbr_i _fbr_lab _fbr_input _fbr_idx
    return 0
  fi

  printf 'Invalid selection\n'
  unset _fbr_i _fbr_lab _fbr_input
  return 1
}

# ---------------------------------------------------------------------------
# Section 13b: Rendering function for tui_radio
# ---------------------------------------------------------------------------

# shellcheck disable=SC2034,SC2154
_tui_render_radio() {
  clear_screen
  _rr_rows=$(tput lines 2>/dev/null || printf '24')
  _rr_cols=$(tput cols 2>/dev/null || printf '80')
  _rr_box_w=$((_rr_cols - 4))
  [ "$_rr_box_w" -lt 40 ] && _rr_box_w=40
  _rr_inner=$((_rr_box_w - 2))
  _rr_x=2
  _rr_r=1

  move_cursor "$_rr_r" "$_rr_x"
  printf '%s' "$TUI_BOX_TL"
  _rr_i=1; while [ "$_rr_i" -le "$_rr_inner" ]; do printf '%s' "$TUI_BOX_H"; _rr_i=$((_rr_i + 1)); done
  printf '%s' "$TUI_BOX_TR"
  _rr_r=$((_rr_r + 1))

  move_cursor "$_rr_r" "$_rr_x"
  printf '%s' "$TUI_BOX_V"
  _rr_tlen=${#_tr_title}
  if [ "$_rr_tlen" -gt "$_rr_inner" ]; then _rr_tlen=$_rr_inner; fi
  _rr_tshow=$(printf '%s' "$_tr_title" | awk -v L="$_rr_tlen" '{print substr($0,1,L)}')
  _rr_pad=$((_rr_inner - ${#_rr_tshow}))
  _rr_pl=$((_rr_pad / 2)); _rr_pr=$((_rr_pad - _rr_pl))
  _rr_j=0; while [ "$_rr_j" -lt "$_rr_pl" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
  printf '%s%s%s' "$TUI_BOLD" "$_rr_tshow" "$TUI_RESET"
  _rr_j=0; while [ "$_rr_j" -lt "$_rr_pr" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rr_r=$((_rr_r + 1))

  if [ -n "$_tr_subtitle" ]; then
    move_cursor "$_rr_r" "$_rr_x"
    printf '%s' "$TUI_BOX_V"
    _rr_slen=${#_tr_subtitle}
    if [ "$_rr_slen" -gt "$_rr_inner" ]; then _rr_slen=$_rr_inner; fi
    _rr_sshow=$(printf '%s' "$_tr_subtitle" | awk -v L="$_rr_slen" '{print substr($0,1,L)}')
    _rr_spad=$((_rr_inner - ${#_rr_sshow}))
    _rr_spl=$((_rr_spad / 2)); _rr_spr=$((_rr_spad - _rr_spl))
    _rr_j=0; while [ "$_rr_j" -lt "$_rr_spl" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
    printf '%s%s%s' "$TUI_DIM" "$_rr_sshow" "$TUI_RESET"
    _rr_j=0; while [ "$_rr_j" -lt "$_rr_spr" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rr_r=$((_rr_r + 1))
  fi

  move_cursor "$_rr_r" "$_rr_x"
  printf '%s' "$TUI_BOX_V"
  _rr_i=1; while [ "$_rr_i" -le "$_rr_inner" ]; do printf '%s' "$TUI_BOX_H"; _rr_i=$((_rr_i + 1)); done
  printf '%s' "$TUI_BOX_V"
  _rr_r=$((_rr_r + 1))

  _rr_status_row=$((_rr_rows - 3))
  _rr_bottom_row=$((_rr_rows - 2))
  _rr_footer_row=$((_rr_rows - 1))
  _tr_page_size=$((_rr_status_row - _rr_r + 1))
  [ "$_tr_page_size" -lt 1 ] && _tr_page_size=1

  if [ "$_tr_scroll" -gt 1 ]; then
    move_cursor "$_rr_r" $((_rr_x + _rr_box_w - 9))
    printf '%s%cmore%s' "$TUI_DIM" '↑' "$TUI_RESET"
  fi

  _rr_end=$((_tr_scroll + _tr_page_size - 1))
  [ "$_rr_end" -gt "$_tr_count" ] && _rr_end=$_tr_count
  _rr_maxlab=$((_rr_inner - 11))
  [ "$_rr_maxlab" -lt 3 ] && _rr_maxlab=3
  _rr_i=$_tr_scroll
  while [ "$_rr_i" -le "$_rr_end" ]; do
    # shellcheck disable=SC2086
    eval "_rr_lab=\$_tr_label_$_rr_i"
    # shellcheck disable=SC2154
    _rr_trunc=$(printf '%s' "$_rr_lab" | awk -v L="$_rr_maxlab" '{print substr($0,1,L)}')
    move_cursor "$_rr_r" "$_rr_x"
    printf '%s' "$TUI_BOX_V"
    if [ "$_tr_selected" -eq "$_rr_i" ]; then
      _rr_prefix="$_tui_radio_glyph_on"
    else
      _rr_prefix="$_tui_radio_glyph_off"
    fi
    if [ "$_rr_i" -eq "$_tr_cursor" ]; then
      printf '%s%s %3d) %s' "$TUI_REV" "$_rr_prefix" "$_rr_i" "$_rr_trunc"
      _rr_used=$((11 + ${#_rr_trunc}))
      _rr_fill=$((_rr_inner - _rr_used))
      [ "$_rr_fill" -gt 0 ] && _rr_j=0 && while [ "$_rr_j" -lt "$_rr_fill" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
      printf '%s' "$TUI_RESET"
    else
      printf '%s %3d) %s' "$_rr_prefix" "$_rr_i" "$_rr_trunc"
      _rr_used=$((11 + ${#_rr_trunc}))
      _rr_fill=$((_rr_inner - _rr_used))
      [ "$_rr_fill" -gt 0 ] && _rr_j=0 && while [ "$_rr_j" -lt "$_rr_fill" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
    fi
    printf '%s' "$TUI_BOX_V"
    _rr_r=$((_rr_r + 1))
    _rr_i=$((_rr_i + 1))
  done

  while [ "$_rr_r" -le "$_rr_status_row" ]; do
    move_cursor "$_rr_r" "$_rr_x"
    printf '%s' "$TUI_BOX_V"
    _rr_j=0; while [ "$_rr_j" -lt "$_rr_inner" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _rr_r=$((_rr_r + 1))
  done

  if [ "$_rr_end" -lt "$_tr_count" ]; then
    _rr_drow=$((_rr_r - 1))
    move_cursor "$_rr_drow" $((_rr_x + _rr_box_w - 9))
    printf '%s%cmore%s' "$TUI_DIM" '↓' "$TUI_RESET"
  fi

  move_cursor "$_rr_status_row" "$_rr_x"
  printf '%s' "$TUI_BOX_V"
  _rr_j=0; while [ "$_rr_j" -lt "$_rr_inner" ]; do printf ' '; _rr_j=$((_rr_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  move_cursor "$_rr_status_row" $((_rr_x + 2))
  if [ -n "$_tr_error_msg" ]; then
    printf '%s%s%s' "$TUI_RED" "$_tr_error_msg" "$TUI_RESET"
  elif [ "$_tr_selected" -gt 0 ]; then
    # shellcheck disable=SC2086
    eval "_rr_sellab=\$_tr_label_$_tr_selected"
    # shellcheck disable=SC2154
    printf 'Selected: %s' "$_rr_sellab"
  else
    printf 'Item %d of %d' "$_tr_cursor" "$_tr_count"
  fi

  move_cursor "$_rr_bottom_row" "$_rr_x"
  printf '%s' "$TUI_BOX_BL"
  _rr_i=1; while [ "$_rr_i" -le "$_rr_inner" ]; do printf '%s' "$TUI_BOX_H"; _rr_i=$((_rr_i + 1)); done
  printf '%s' "$TUI_BOX_BR"

  move_cursor "$_rr_footer_row" "$_rr_x"
  if [ "$_tr_show_help" = "true" ]; then
    _rr_ft='Up/Dn Move  Space=Select  Enter=Confirm  Esc=Cancel  PgUp/PgDn Page  Home/End  j/k Vi  ? Less'
  else
    _rr_ft='Up/Dn Move  Space=Select  Enter=Confirm  Esc=Cancel  ?=More'
  fi
  printf '%s%s%s' "$TUI_DIM" "$_rr_ft" "$TUI_RESET"

  printf '%s[?25l' "$ESC"

  unset _rr_rows _rr_cols _rr_box_w _rr_inner _rr_x _rr_r _rr_i _rr_j
  unset _rr_tlen _rr_tshow _rr_pad _rr_pl _rr_pr _rr_slen _rr_sshow _rr_spad _rr_spl _rr_spr
  unset _rr_status_row _rr_bottom_row _rr_footer_row _rr_end _rr_maxlab _rr_lab _rr_trunc
  unset _rr_prefix _rr_used _rr_fill _rr_drow _rr_ft _rr_sellab
}

# ---------------------------------------------------------------------------
# Section 13c: tui_radio() — Single-select radio button widget
# ---------------------------------------------------------------------------

# tui_radio title subtitle item1 item2 ... [--default N]
# Single-select radio widget with (•)/(○) indicators.
# Up/Down navigate, SPACE selects, ENTER confirms, Esc cancels.
# --default N pre-selects the Nth item (0-based index).
# Prints the 0-based index of the selected item to stdout.
# Sets TUI_RESULT to the same 0-based index.
# Returns 0 on success, 1 on cancel.
tui_radio() {
  _tr_title=$1; _tr_subtitle=$2; shift 2

  _tr_count=0
  _tr_cursor=1
  _tr_scroll=1
  _tr_selected=0
  _tr_default=0
  _tr_show_help=false
  _tr_page_size=1
  _tr_error_msg=''

  _tr_parse_mode=items
  for _tr_arg in "$@"; do
    if [ "$_tr_arg" = "--default" ]; then
      _tr_parse_mode=default; continue
    fi
    if [ "$_tr_parse_mode" = "default" ]; then
      _tr_default=$((_tr_arg + 1))
      _tr_selected=$_tr_default
      _tr_cursor=$_tr_default
      _tr_parse_mode=items; continue
    fi
    _tr_count=$((_tr_count + 1))
    _tr_safe=$(printf '%s' "$_tr_arg" | sed "s/'/'\\\\''/g")
    eval "_tr_label_$_tr_count='$_tr_safe'"
  done
  unset _tr_arg _tr_safe _tr_parse_mode

  if [ "$_tr_count" -eq 0 ]; then
    return 1
  fi

  # Clamp cursor/selected to valid range
  [ "$_tr_cursor" -gt "$_tr_count" ] && _tr_cursor=1
  [ "$_tr_selected" -gt "$_tr_count" ] && _tr_selected=0

  if [ "$_tui_use_tui" = "false" ]; then
    _tui_radio_fallback
    _tr_rc=$?
    _tr_i=1
    while [ "$_tr_i" -le "$_tr_count" ]; do
      # shellcheck disable=SC2086
      eval "unset _tr_label_$_tr_i"
      _tr_i=$((_tr_i + 1))
    done
    _tr_ret=$_tr_rc
    unset _tr_title _tr_subtitle _tr_count _tr_cursor _tr_scroll
    unset _tr_selected _tr_default _tr_show_help _tr_page_size _tr_error_msg
    unset _tr_i _tr_rc _tr_bottom _tr_max_scroll
    return $_tr_ret
  fi

  tui_init

  while :; do
    _tui_render_radio
    # shellcheck disable=SC2034
    _tui_read_key
    key="$_tui_rk_result"

    case "$key" in
      "$TUI_KEY_SPACE")
        _tr_selected=$_tr_cursor
        _tr_error_msg=''
        ;;
      "$TUI_KEY_ENTER")
        if [ "$_tr_selected" -eq 0 ]; then
          _tr_error_msg="Select an option"
        else
          tui_restore
          _tr_idx=$((_tr_selected - 1))
          TUI_RESULT=$_tr_idx
          printf '%d\n' "$_tr_idx"
          _tr_i=1
          while [ "$_tr_i" -le "$_tr_count" ]; do
            # shellcheck disable=SC2086
            eval "unset _tr_label_$_tr_i"
            _tr_i=$((_tr_i + 1))
          done
          unset _tr_idx _tr_i _tr_title _tr_subtitle _tr_count _tr_cursor
          unset _tr_scroll _tr_selected _tr_default _tr_show_help _tr_page_size _tr_error_msg
          unset _tr_bottom _tr_max_scroll
          return 0
        fi
        ;;
      "$TUI_KEY_UP")
        if [ "$_tr_cursor" -gt 1 ]; then
          _tr_cursor=$((_tr_cursor - 1))
          if [ "$_tr_cursor" -lt "$_tr_scroll" ]; then
            _tr_scroll=$((_tr_scroll - 1))
          fi
        fi
        _tr_error_msg=''
        ;;
      "$TUI_KEY_DOWN")
        if [ "$_tr_cursor" -lt "$_tr_count" ]; then
          _tr_cursor=$((_tr_cursor + 1))
          _tr_bottom=$((_tr_scroll + _tr_page_size - 1))
          if [ "$_tr_cursor" -gt "$_tr_bottom" ]; then
            _tr_scroll=$((_tr_scroll + 1))
          fi
        fi
        _tr_error_msg=''
        ;;
      "$TUI_KEY_PGUP")
        _tr_scroll=$((_tr_scroll - _tr_page_size))
        [ "$_tr_scroll" -lt 1 ] && _tr_scroll=1
        _tr_cursor=$_tr_scroll
        _tr_error_msg=''
        ;;
      "$TUI_KEY_PGDN")
        _tr_scroll=$((_tr_scroll + _tr_page_size))
        _tr_max_scroll=$((_tr_count - _tr_page_size + 1))
        [ "$_tr_max_scroll" -lt 1 ] && _tr_max_scroll=1
        [ "$_tr_scroll" -gt "$_tr_max_scroll" ] && _tr_scroll=$_tr_max_scroll
        _tr_bottom=$((_tr_scroll + _tr_page_size - 1))
        [ "$_tr_bottom" -gt "$_tr_count" ] && _tr_bottom=$_tr_count
        _tr_cursor=$_tr_bottom
        _tr_error_msg=''
        ;;
      "$TUI_KEY_HOME")
        _tr_cursor=1; _tr_scroll=1; _tr_error_msg=''
        ;;
      "$TUI_KEY_END")
        _tr_cursor=$_tr_count
        _tr_max_scroll=$((_tr_count - _tr_page_size + 1))
        [ "$_tr_max_scroll" -lt 1 ] && _tr_max_scroll=1
        _tr_scroll=$_tr_max_scroll
        _tr_error_msg=''
        ;;
      "$TUI_KEY_ESC"|"$TUI_KEY_Q")
        tui_restore
        TUI_RESULT=''
        _tr_i=1
        while [ "$_tr_i" -le "$_tr_count" ]; do
          # shellcheck disable=SC2086
          eval "unset _tr_label_$_tr_i"
          _tr_i=$((_tr_i + 1))
        done
        unset _tr_i _tr_title _tr_subtitle _tr_count _tr_cursor _tr_scroll
        unset _tr_selected _tr_default _tr_show_help _tr_page_size _tr_error_msg
        unset _tr_bottom _tr_max_scroll
        return 1
        ;;
      "$TUI_KEY_HELP")
        if [ "$_tr_show_help" = "true" ]; then
          _tr_show_help=false
        else
          _tr_show_help=true
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Section 14: Yes/No fallback prompt
# ---------------------------------------------------------------------------

# _tui_yesno_fallback
# Uses _ty_* globals set by tui_yesno() for title, message, and selection.
# Prompts the user for y/n input with the pre-selected default shown.
# Prints 'yes' or 'no' to stdout, sets TUI_RESULT.
# Returns 0 on selection, 1 on cancel/invalid.
_tui_yesno_fallback() {
  printf '\n'
  printf '  %s\n' "$_ty_title"
  printf '  %s\n' "$_ty_message"
  printf '\n'
  if [ "$_ty_selected" = "yes" ]; then
    printf '  [x] Yes    [ ] No\n'
  else
    printf '  [ ] Yes    [x] No\n'
  fi
  printf '\n'
  printf 'Enter y/n (default: %s): ' "$_ty_selected"
  _ty_input=''
  IFS= read -r _ty_input </dev/tty 2>/dev/null || read -r _ty_input

  case "$_ty_input" in
    [yY]*) _ty_result="yes" ;;
    [nN]*) _ty_result="no" ;;
    '') _ty_result="$_ty_selected" ;;
    *)
      unset _ty_title _ty_message _ty_default _ty_selected _ty_input
      return 1
      ;;
  esac

  printf '%s\n' "$_ty_result"
  TUI_RESULT="$_ty_result"
  unset _ty_title _ty_message _ty_default _ty_selected _ty_input
  return 0
}

# ---------------------------------------------------------------------------
# Section 14a: Rendering function for tui_yesno
# ---------------------------------------------------------------------------

_tui_render_yesno() {
  clear_screen
  _ty_rows=$(tput lines 2>/dev/null || printf '24')
  _ty_cols=$(tput cols 2>/dev/null || printf '80')
  _ty_box_w=50
  [ "$_ty_box_w" -gt "$_ty_cols" ] && _ty_box_w=$((_ty_cols - 4))
  _ty_box_h=8
  _ty_x=$(( (_ty_cols - _ty_box_w) / 2 ))
  _ty_y=$(( (_ty_rows - _ty_box_h) / 2 ))
  [ "$_ty_x" -lt 1 ] && _ty_x=1
  [ "$_ty_y" -lt 1 ] && _ty_y=1
  _ty_inner=$((_ty_box_w - 2))

  # Draw the box frame with centered title
  _tui_draw_box "$_ty_x" "$_ty_y" "$_ty_box_w" "$_ty_box_h" "$_ty_title"

  # Message (centered on row _ty_y+2)
  _ty_msg_row=$((_ty_y + 2))
  _ty_msg_display=$(printf '%s' "$_ty_message" | awk -v L="$_ty_inner" '{print substr($0,1,L)}')
  _ty_msg_pad=$(( (_ty_inner - ${#_ty_msg_display}) / 2 ))
  [ "$_ty_msg_pad" -lt 0 ] && _ty_msg_pad=0
  move_cursor "$_ty_msg_row" $((_ty_x + 1 + _ty_msg_pad))
  printf '%s' "$_ty_msg_display"

  # Yes/No buttons (centered on row _ty_y+4)
  _ty_btn_row=$((_ty_y + 4))
  _ty_yes_label="    Yes    "
  _ty_no_label="    No     "
  _ty_btn_total=$(( ${#_ty_yes_label} + ${#_ty_no_label} + 2 ))
  _ty_btn_start=$(( _ty_x + (_ty_box_w - _ty_btn_total) / 2 ))

  # Render Yes button
  move_cursor "$_ty_btn_row" "$_ty_btn_start"
  if [ "$_ty_selected" = "yes" ]; then
    printf '%s%s%s' "$TUI_REV" "$_ty_yes_label" "$TUI_RESET"
  else
    printf '%s' "$_ty_yes_label"
  fi

  # Gap between buttons
  printf '  '

  # Render No button
  if [ "$_ty_selected" = "no" ]; then
    printf '%s%s%s' "$TUI_REV" "$_ty_no_label" "$TUI_RESET"
  else
    printf '%s' "$_ty_no_label"
  fi

  # Footer (on the bottom border row of the box)
  _ty_footer_row=$((_ty_y + _ty_box_h - 1))
  move_cursor "$_ty_footer_row" "$_ty_x"
  if [ "$_ty_show_help" = "true" ]; then
    _ty_ft='←→ Move  Enter=Confirm  Esc=Cancel  ? Less'
  else
    _ty_ft='←→ Move  Enter=Confirm  Esc=Cancel  ? Keys'
  fi
  printf '%s%s%s' "$TUI_DIM" "$_ty_ft" "$TUI_RESET"

  printf '%s[?25l' "$ESC"

  unset _ty_rows _ty_cols _ty_box_w _ty_box_h _ty_x _ty_y _ty_inner
  unset _ty_msg_row _ty_msg_display _ty_msg_pad _ty_btn_row _ty_btn_total _ty_btn_start
  unset _ty_yes_label _ty_no_label _ty_footer_row _ty_ft
}

# ---------------------------------------------------------------------------
# Section 14b: tui_yesno() — Confirmation dialog widget
# ---------------------------------------------------------------------------

# tui_yesno title message [default]
# Full-screen centered modal confirmation dialog with Yes/No buttons.
# Left/Right arrows toggle highlight. ENTER confirms. Esc cancels.
# default: "yes" or "no" (defaults to "no" for safety).
# Returns literal 'yes' or 'no' string to stdout and TUI_RESULT.
# Returns 0 on confirm, 1 on cancel.
tui_yesno() {
  _ty_title=$1; _ty_message=$2
  _ty_default="${3:-no}"
  _ty_selected=''
  _ty_show_help=false

  # Set initial selection based on default (D-14: "No" by default)
  case "$_ty_default" in
    yes|Yes|YES|y|Y) _ty_selected="yes" ;;
    *) _ty_selected="no" ;;
  esac

  if [ "$_tui_use_tui" = "false" ]; then
    _tui_yesno_fallback
    return $?
  fi

  tui_init

  while :; do
    _tui_render_yesno
    # shellcheck disable=SC2034
    _tui_read_key
    key="$_tui_rk_result"

    case "$key" in
      "$TUI_KEY_LEFT"|"$TUI_KEY_RIGHT")
        # Toggle between yes and no (D-13)
        if [ "$_ty_selected" = "yes" ]; then
          _ty_selected="no"
        else
          _ty_selected="yes"
        fi
        ;;
      "$TUI_KEY_ENTER")
        tui_restore
        TUI_RESULT="$_ty_selected"
        printf '%s\n' "$_ty_selected"
        unset _ty_title _ty_message _ty_default _ty_selected _ty_show_help
        return 0
        ;;
      "$TUI_KEY_ESC")
        tui_restore
        TUI_RESULT=''
        unset _ty_title _ty_message _ty_default _ty_selected _ty_show_help
        return 1
        ;;
      "$TUI_KEY_HELP")
        if [ "$_ty_show_help" = "true" ]; then
          _ty_show_help=false
        else
          _ty_show_help=true
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Section 15: tui_text_input() — Freeform text input widget
# ---------------------------------------------------------------------------

# tui_text_input title prompt [default_value]
# Full-screen centered modal text entry widget with inline line editing.
# Backspace, Delete, Left/Right arrows, Home/End, reverse-video block cursor.
# ENTER confirms (accepts empty input), Esc cancels.
# Returns typed string via stdout and TUI_RESULT.
# Returns 0 on Enter, 1 on Esc.
tui_text_input() {
  _ti_title=$1; _ti_prompt=$2
  _ti_value="${3:-}"
  _ti_cursor=${#_ti_value}
  _ti_show_help=false
  _ti_maxlen=256

  # Cursor movement helpers
  _ti_cursor_left() {
    if [ "$_ti_cursor" -gt 0 ]; then
      _ti_cursor=$((_ti_cursor - 1))
    fi
  }

  _ti_cursor_right() {
    _ti_max_pos=${#_ti_value}
    if [ "$_ti_cursor" -lt "$_ti_max_pos" ]; then
      _ti_cursor=$((_ti_cursor + 1))
    fi
  }

  # Insert character at cursor position
  _ti_insert_char() {
    _ti_ch=$1
    if [ "$_ti_cursor" -eq 0 ]; then
      _ti_value="${_ti_ch}${_ti_value}"
    elif [ "$_ti_cursor" -ge "${#_ti_value}" ]; then
      _ti_value="${_ti_value}${_ti_ch}"
    else
      _ti_left=$(printf '%s' "$_ti_value" | awk -v P="$_ti_cursor" '{print substr($0,1,P)}')
      _ti_right=$(printf '%s' "$_ti_value" | awk -v P=$((_ti_cursor + 1)) '{print substr($0,P)}')
      _ti_value="${_ti_left}${_ti_ch}${_ti_right}"
    fi
    _ti_cursor=$((_ti_cursor + 1))
  }

  # Delete character at cursor (forward delete)
  _ti_delete_char() {
    if [ "$_ti_cursor" -lt "${#_ti_value}" ]; then
      _ti_left=$(printf '%s' "$_ti_value" | awk -v P="$_ti_cursor" '{print substr($0,1,P)}')
      _ti_right=$(printf '%s' "$_ti_value" | awk -v P=$((_ti_cursor + 2)) '{print substr($0,P)}')
      _ti_value="${_ti_left}${_ti_right}"
    fi
  }

  # Backspace: delete character before cursor
  _ti_backspace_char() {
    if [ "$_ti_cursor" -gt 0 ]; then
      _ti_cursor=$((_ti_cursor - 1))
      _ti_left=$(printf '%s' "$_ti_value" | awk -v P="$_ti_cursor" '{print substr($0,1,P)}')
      _ti_right=$(printf '%s' "$_ti_value" | awk -v P=$((_ti_cursor + 2)) '{print substr($0,P)}')
      _ti_value="${_ti_left}${_ti_right}"
    fi
  }

  # Fallback: simple read prompt when no TTY
  _ti_fallback() {
    printf '\n'
    printf '  %s\n' "$_ti_title"
    printf '  %s\n' "$_ti_prompt"
    if [ -n "$_ti_value" ]; then
      printf '  Default: %s\n' "$_ti_value"
    fi
    printf '  > '
    _ti_rc=0
    IFS= read -r _ti_input </dev/tty 2>/dev/null || { IFS= read -r _ti_input; _ti_rc=$?; }
    if [ "$_ti_rc" -ne 0 ] || { [ -z "$_ti_input" ] && [ -n "$_ti_value" ]; }; then
      _ti_input="$_ti_value"
    fi
    printf '%s\n' "$_ti_input"
    TUI_RESULT="$_ti_input"
    return 0
  }

  if [ "$_tui_use_tui" = "false" ]; then
    _ti_fallback
    return 0
  fi

  # Full-screen rendering
  _ti_render() {
    clear_screen
    _ti_rows=$(tput lines 2>/dev/null || printf '24')
    _ti_cols=$(tput cols 2>/dev/null || printf '80')

    _ti_box_w=60
    [ "$_ti_box_w" -gt "$_ti_cols" ] && _ti_box_w=$((_ti_cols - 4))
    _ti_box_h=7
    _ti_x=$(( (_ti_cols - _ti_box_w) / 2 ))
    _ti_y=$(( (_ti_rows - _ti_box_h) / 2 ))
    [ "$_ti_x" -lt 1 ] && _ti_x=1
    [ "$_ti_y" -lt 1 ] && _ti_y=1

    _tui_draw_box "$_ti_x" "$_ti_y" "$_ti_box_w" "$_ti_box_h" "$_ti_title"

    _ti_inner=$((_ti_box_w - 2))

    # Prompt label (first body row: y+3)
    _ti_prompt_row=$((_ti_y + 3))
    _ti_prompt_display=$(printf '%s' "$_ti_prompt" | awk -v L="$_ti_inner" '{print substr($0,1,L)}')
    _ti_prompt_pad=$(( (_ti_inner - ${#_ti_prompt_display}) / 2 ))
    [ "$_ti_prompt_pad" -lt 0 ] && _ti_prompt_pad=0
    move_cursor "$_ti_prompt_row" $((_ti_x + 1 + _ti_prompt_pad))
    printf '%s' "$_ti_prompt_display"

    # Input field (third body row: y+5)
    _ti_input_row=$((_ti_y + 5))
    _ti_input_width=$((_ti_inner - 4))
    [ "$_ti_input_width" -lt 10 ] && _ti_input_width=10

    move_cursor "$_ti_input_row" "$_ti_x"
    printf '%s ' "$TUI_BOX_V"

    # Truncate value to fit input width, show visible portion around cursor
    _ti_val_len=${#_ti_value}
    _ti_input_start=0
    if [ "$_ti_val_len" -gt "$_ti_input_width" ]; then
      _ti_input_start=$((_ti_cursor - _ti_input_width / 2))
      [ "$_ti_input_start" -lt 0 ] && _ti_input_start=0
      _ti_max_start=$((_ti_val_len - _ti_input_width))
      [ "$_ti_input_start" -gt "$_ti_max_start" ] && _ti_input_start=$_ti_max_start
    fi

    _ti_visible=$(printf '%s' "$_ti_value" | awk -v S=$((_ti_input_start + 1)) -v L="$_ti_input_width" '{print substr($0,S,L)}')
    _ti_vis_len=${#_ti_visible}
    _ti_cursor_vis=$((_ti_cursor - _ti_input_start))

    # Render each character of visible portion
    _ti_j=0; _ti_rendered=0
    while [ "$_ti_j" -lt "$_ti_vis_len" ]; do
      _ti_ch=$(printf '%s' "$_ti_visible" | awk -v P=$((_ti_j + 1)) '{print substr($0,P,1)}')
      if [ "$_ti_j" -eq "$_ti_cursor_vis" ] && [ "$_ti_cursor" -lt "$_ti_val_len" ]; then
        printf '%s%s%s' "$TUI_REV" "$_ti_ch" "$TUI_RESET"
      else
        printf '%s' "$_ti_ch"
      fi
      _ti_j=$((_ti_j + 1))
      _ti_rendered=$((_ti_rendered + 1))
    done

    # If cursor is past all visible chars, show inverse block cursor (space)
    if [ "$_ti_cursor" -ge "$_ti_val_len" ]; then
      printf '%s %s' "$TUI_REV" "$TUI_RESET"
      _ti_rendered=$((_ti_rendered + 1))
    fi

    # Fill remaining space in input field
    _ti_fill=$((_ti_input_width - _ti_rendered))
    _ti_k=0
    while [ "$_ti_k" -lt "$_ti_fill" ]; do
      printf ' '
      _ti_k=$((_ti_k + 1))
    done

    printf ' %s' "$TUI_BOX_V"

    # Footer on bottom border row
    _ti_footer_row=$((_ti_y + _ti_box_h - 1))
    move_cursor "$_ti_footer_row" "$_ti_x"
    if [ "$_ti_show_help" = "true" ]; then
      _ti_ft='Enter=Confirm  Esc=Cancel  Backspace  ←→ Cursor  Home/End  Delete  ? Less'
    else
      _ti_ft='Enter=Confirm  Esc=Cancel  Backspace  ←→ Cursor  ? Keys'
    fi
    printf '%s%s%s' "$TUI_DIM" "$_ti_ft" "$TUI_RESET"

    printf '%s[?25l' "$ESC"
  }

  tui_init

  while :; do
    _ti_render

    # Read raw character byte (not _tui_read_key — avoids jinx key conflicts)
    _tui_read_char || continue
    _ti_byte="$_tui_rc_char"

    case "$_ti_byte" in
      "$(printf '\r')"|"$(printf '\n')")
        # Enter — confirm
        tui_restore
        TUI_RESULT="$_ti_value"
        printf '%s\n' "$_ti_value"
        unset _ti_title _ti_prompt _ti_value _ti_cursor _ti_show_help _ti_maxlen
        unset _ti_byte _ti_input
        return 0
        ;;
      "$(printf '\033')")
        # Escape — could be plain Esc or start of escape sequence
        _ti_key_timeout=${TUI_KEY_TIMEOUT:-10}
        stty min 0 time "$_ti_key_timeout" 2>/dev/null || true
        if _tui_read_char; then
          _ti_seq1="$_tui_rc_char"
          if [ "$_ti_seq1" = '[' ] || [ "$_ti_seq1" = 'O' ]; then
            if _tui_read_char; then
              _ti_seq2="$_tui_rc_char"
              stty min 1 time 0 2>/dev/null || true
              case "$_ti_seq2" in
                C) _ti_cursor_right ;;     # Right arrow
                D) _ti_cursor_left ;;      # Left arrow
                H) _ti_cursor=0 ;;         # Home
                F) _ti_cursor=${#_ti_value} ;;  # End
                A|B) ;;                    # Up/Down — ignore in text input
                3)
                  # Delete key: \033[3~
                  _tui_read_char || true
                  if [ "$_tui_rc_char" = '~' ]; then
                    _ti_delete_char
                  fi
                  ;;
                1|4)
                  # Home (\033[1~) or End (\033[4~)
                  _tui_read_char || true
                  if [ "$_tui_rc_char" = '~' ]; then
                    case "$_ti_seq2" in
                      1) _ti_cursor=0 ;;
                      4) _ti_cursor=${#_ti_value} ;;
                    esac
                  fi
                  ;;
              esac
            else
              stty min 1 time 0 2>/dev/null || true
            fi
          else
            stty min 1 time 0 2>/dev/null || true
            # Non-[/O after Esc: treat as printable if ASCII
            _ti_ord=$(printf '%d' "'$_ti_seq1" 2>/dev/null || true)
            if [ -n "$_ti_ord" ] && [ "$_ti_ord" -ge 32 ] && [ "$_ti_ord" -le 126 ]; then
              if [ "${#_ti_value}" -lt "$_ti_maxlen" ]; then
                _ti_insert_char "$_ti_seq1"
              fi
            fi
          fi
        else
          stty min 1 time 0 2>/dev/null || true
          # Timeout: plain Esc — cancel
          tui_restore
          TUI_RESULT=''
          unset _ti_title _ti_prompt _ti_value _ti_cursor _ti_show_help _ti_maxlen
          unset _ti_byte _ti_input _ti_key_timeout _ti_seq1 _ti_seq2 _ti_ord
          return 1
        fi
        unset _ti_key_timeout _ti_seq1 _ti_seq2 _ti_ord
        ;;
      "$(printf '\010')"|"$(printf '\177')")
        # Backspace (BS or DEL)
        _ti_backspace_char
        ;;
      "$(printf '\t')"|"$(printf '\004')")
        # Tab / Ctrl+D: ignore
        ;;
      '?')
        if [ "$_ti_show_help" = "true" ]; then
          _ti_show_help=false
        else
          _ti_show_help=true
        fi
        ;;
      *)
        # Check for printable ASCII (0x20-0x7E)
        _ti_ord=$(printf '%d' "'$_ti_byte" 2>/dev/null || true)
        if [ -n "$_ti_ord" ] && [ "$_ti_ord" -ge 32 ] && [ "$_ti_ord" -le 126 ]; then
          if [ "${#_ti_value}" -lt "$_ti_maxlen" ]; then
            _ti_insert_char "$_ti_byte"
          fi
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Section 16: Async spinner widget
# ---------------------------------------------------------------------------

# Detect UTF-8 support for spinner character selection.
# Called at module scope — mirrors _tui_detect_box_chars pattern.
_flu_spinner_utf8=false

_flu_spinner_detect_utf8() {
  _locale="${LANG:-}${LC_ALL:-}${LC_CTYPE:-}"
  case "$_locale" in
    *UTF-8*|*utf-8*|*utf8*|*UTF8*) _flu_spinner_utf8=true ;;
    *) _flu_spinner_utf8=false ;;
  esac
  unset _locale
}

_flu_spinner_detect_utf8

# Spinner state: PID of background process (empty when idle), frame counter.
_flu_spinner_pid=''
_flu_spinner_frame=0

# _flu_spinner_render() — render one frame of the spinner animation.
# Called by the background loop. Uses _flu_spinner_frame to select the
# spinner character, renders via _tui_printf_at in TUI mode or plain
# printf with \r overwrite in fallback mode.
# shellcheck disable=SC2034
_flu_spinner_render() {
  _flu_spinner_char=''

  if [ "$_flu_spinner_utf8" = "true" ]; then
    # Braille spinner: 10-frame smooth animation
    case $(( _flu_spinner_frame % 10 )) in
      0) _flu_spinner_char='⠋' ;; 1) _flu_spinner_char='⠙' ;;
      2) _flu_spinner_char='⠹' ;; 3) _flu_spinner_char='⠸' ;;
      4) _flu_spinner_char='⠼' ;; 5) _flu_spinner_char='⠴' ;;
      6) _flu_spinner_char='⠦' ;; 7) _flu_spinner_char='⠧' ;;
      8) _flu_spinner_char='⠇' ;; 9) _flu_spinner_char='⠏' ;;
    esac
  else
    # ASCII spinner: 4-frame classic animation
    case $(( _flu_spinner_frame % 4 )) in
      0) _flu_spinner_char='|' ;;
      1) _flu_spinner_char='/' ;;
      2) _flu_spinner_char='-' ;;
      3) _flu_spinner_char='\' ;;
    esac
  fi

  if [ "$_tui_use_tui" = "false" ]; then
    # Non-TUI mode: simple text line with carriage-return overwrite
    printf '\r  Working... %s' "$_flu_spinner_char"
  else
    # TUI mode: positioned output at bottom of screen, centered
    _flu_render_row=$(tput lines 2>/dev/null || printf '24')
    _flu_render_col=$(tput cols 2>/dev/null || printf '80')
    _flu_render_col=$(( (_flu_render_col - 12) / 2 ))
    [ "$_flu_render_col" -lt 1 ] && _flu_render_col=1
    _tui_printf_at "$_flu_render_row" "$_flu_render_col" \
      "  ${TUI_CYAN}Loading${TUI_RESET} %s" "$_flu_spinner_char"
    unset _flu_render_row _flu_render_col
  fi

  _flu_spinner_frame=$((_flu_spinner_frame + 1))
}

# flu_spinner_start() — start the spinner background process.
# Guard: if spinner is already running, return immediately (idempotent).
# Launches a background subshell that calls _flu_spinner_render in a loop.
flu_spinner_start() {
  if [ -n "${_flu_spinner_pid:-}" ]; then
    return 0
  fi

  _flu_spinner_frame=0
  (while :; do _flu_spinner_render; sleep 0.1; done) &
  _flu_spinner_pid=$!
}

# flu_spinner_stop() — stop the spinner and clean up the screen area.
# Guard: if no spinner is running, return immediately (no-op safe).
# Kills the background process, waits for reaping, then clears the
# spinner text from the screen.
flu_spinner_stop() {
  if [ -z "${_flu_spinner_pid:-}" ]; then
    return 0
  fi

  kill "$_flu_spinner_pid" 2>/dev/null
  wait "$_flu_spinner_pid" 2>/dev/null

  if [ "$_tui_use_tui" = "false" ]; then
    # Move to next line after the carriage-return-overwritten spinner text
    printf '\n'
  else
    # Move cursor to spinner row and clear the line
    _flu_stop_row=$(tput lines 2>/dev/null || printf '24')
    move_cursor "$_flu_stop_row" 1
    _tui_clear_line
    unset _flu_stop_row
  fi

  _flu_spinner_pid=''
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
    if [ "${1:-}" = "--demo-radio" ]; then
      shift
      if [ $# -eq 0 ]; then
        set -- "Light theme" "Dark theme" "System default"
      fi
      tui_radio "Radio Demo" "Choose a theme:" "$@" --default 1
      _demo_rc=$?
      if [ $_demo_rc -eq 0 ]; then
        printf 'Selected index: %s\n' "$TUI_RESULT"
      else
        printf 'Cancelled\n'
      fi
      exit $_demo_rc
    fi
    if [ "${1:-}" = "--demo-yesno" ]; then
      shift
      tui_yesno "Confirm Removal" "${1:-Remove all selected packages?}" "${2:-no}"
      _demo_rc=$?
      if [ $_demo_rc -eq 0 ]; then
        printf 'Result: %s\n' "$TUI_RESULT"
      else
        printf 'Cancelled\n'
      fi
      exit $_demo_rc
    fi
    if [ "${1:-}" = "--demo-text-input" ]; then
      shift
      tui_text_input "Text Input Demo" "Enter your name:" "${1:-}"
      _demo_rc=$?
      if [ $_demo_rc -eq 0 ]; then
        printf 'You entered: %s\n' "$TUI_RESULT"
      else
        printf 'Cancelled\n'
      fi
      exit $_demo_rc
    fi
    if [ "${1:-}" = "--demo-spinner" ]; then
      shift
      printf 'Spinner demo — starting spinner for 3 seconds...\n'
      flu_spinner_start
      sleep 3
      flu_spinner_stop
      printf 'Spinner stopped.\n'
      exit 0
    fi
    if [ $# -gt 0 ]; then
      tui_select "$@"
      exit $?
    fi
    ;;
esac
