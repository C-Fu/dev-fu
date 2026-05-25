#!/usr/bin/env sh
# menu.sh — Hierarchical menu DSL parser for flu.sh
#
# Parses pipe-delimited menu definition files and provides
# tree query functions for the navigation engine.
# Sources tui.sh for TUI primitives.
#
# Usage:
#   . ./tui.sh
#   . ./menu.sh
#   flu_menu_load "menu.db"
#   flu_menu_get_children ""                  # Level 1 items
#   flu_menu_get_children "Developer Tools"   # Level 2 items under Developer Tools
#   flu_menu_get_children "Developer Tools|Languages"  # Level 3 items
#
# No external dependencies. No bashisms. Every line passes shellcheck -s sh.
#
# shellcheck disable=SC2034  # Library constants are used by callers who source this file

# Functions:
#   flu_menu_load <file>            — Parse DSL file into indexed arrays
#   flu_menu_get_children <path>    — Get children of a menu path (stdout + _fm_child_N)
#   flu_menu_is_leaf <path>         — Check if path is a leaf node (returns 0/1)
#   flu_menu_get_breadcrumb <path>  — Convert path to "Main Menu > A > B" string
#   flu_menu_get_action <path>      — Get action field for a full L1|L2|L3 path
#   _flu_menu_render                — Render current menu level (internal, TUI only)
#   flu_menu_navigate <dsl_file>    — Hierarchical menu navigation engine
#   _flu_menu_navigate_fallback     — Non-TTY numbered prompt fallback (internal)

# ---------------------------------------------------------------------------
# Section 1: Source tui.sh if not already sourced
# ---------------------------------------------------------------------------

if [ -z "${TUI_RESET:-}" ]; then
  # tui.sh not sourced — source it
  _menu_script_dir=$(cd "$(dirname "$0")" && pwd)
  # shellcheck disable=SC1091
  . "$_menu_script_dir/tui.sh"
  unset _menu_script_dir
fi

# ---------------------------------------------------------------------------
# Section 2: flu_menu_load() — Parse DSL file into indexed arrays
# ---------------------------------------------------------------------------

# flu_menu_load <dsl_file>
# Parses a pipe-delimited menu definition file into indexed storage.
# Builds _fm_line_N variables: each is the raw "L1|L2|L3|action" string.
# Also populates _fm_l1_N (unique Level 1 labels), _fm_l2_N (L1|L2 unique),
# and _fm_l3_N (L1|L2|L3 unique) for fast child lookup.
# Globals set: _fm_count, _fm_line_1..N, _fm_l1_count, _fm_l1_1..N,
#              _fm_l2_count, _fm_l2_1..N, _fm_l3_count, _fm_l3_1..N
# shellcheck disable=SC2154  # eval-assigned variables
flu_menu_load() {
  _fm_dsl=$1
  if [ ! -f "$_fm_dsl" ]; then
    printf 'Error: menu definition not found: %s\n' "$_fm_dsl" >&2
    return 1
  fi

  # Parse all non-comment, non-empty lines into _fm_line_N
  _fm_count=0
  while IFS= read -r _fm_raw; do
    case "$_fm_raw" in
      '#'*|'') continue ;;
    esac
    _fm_count=$((_fm_count + 1))
    _fm_safe=$(printf '%s' "$_fm_raw" | sed "s/'/'\\\\''/g")
    eval "_fm_line_$_fm_count='$_fm_safe'"
  done < "$_fm_dsl"

  # Build Level 1 unique list
  _fm_l1_count=0
  _fm_i=1
  while [ "$_fm_i" -le "$_fm_count" ]; do
    eval "_fm_line=\$_fm_line_$_fm_i"
    _fm_l1=$(printf '%s' "$_fm_line" | awk -F'|' '{print $1}')
    # Check if already in L1 list
    _fm_found=false
    _fm_j=1
    while [ "$_fm_j" -le "$_fm_l1_count" ]; do
      eval "_fm_exist=\$_fm_l1_$_fm_j"
      if [ "$_fm_l1" = "$_fm_exist" ]; then
        _fm_found=true
        break
      fi
      _fm_j=$((_fm_j + 1))
    done
    if [ "$_fm_found" = "false" ]; then
      _fm_l1_count=$((_fm_l1_count + 1))
      _fm_safe=$(printf '%s' "$_fm_l1" | sed "s/'/'\\\\''/g")
      eval "_fm_l1_$_fm_l1_count='$_fm_safe'"
    fi
    _fm_i=$((_fm_i + 1))
  done

  # Build Level 2 unique list (L1|L2 combined)
  _fm_l2_count=0
  _fm_i=1
  while [ "$_fm_i" -le "$_fm_count" ]; do
    eval "_fm_line=\$_fm_line_$_fm_i"
    _fm_l2=$(printf '%s' "$_fm_line" | awk -F'|' '{print $1 "|" $2}')
    _fm_found=false
    _fm_j=1
    while [ "$_fm_j" -le "$_fm_l2_count" ]; do
      eval "_fm_exist=\$_fm_l2_$_fm_j"
      if [ "$_fm_l2" = "$_fm_exist" ]; then
        _fm_found=true
        break
      fi
      _fm_j=$((_fm_j + 1))
    done
    if [ "$_fm_found" = "false" ]; then
      _fm_l2_count=$((_fm_l2_count + 1))
      _fm_safe=$(printf '%s' "$_fm_l2" | sed "s/'/'\\\\''/g")
      eval "_fm_l2_$_fm_l2_count='$_fm_safe'"
    fi
    _fm_i=$((_fm_i + 1))
  done

  # Build Level 3 unique list (L1|L2|L3 combined)
  _fm_l3_count=0
  _fm_i=1
  while [ "$_fm_i" -le "$_fm_count" ]; do
    eval "_fm_line=\$_fm_line_$_fm_i"
    _fm_l3=$(printf '%s' "$_fm_line" | awk -F'|' '{print $1 "|" $2 "|" $3}')
    _fm_found=false
    _fm_j=1
    while [ "$_fm_j" -le "$_fm_l3_count" ]; do
      eval "_fm_exist=\$_fm_l3_$_fm_j"
      if [ "$_fm_l3" = "$_fm_exist" ]; then
        _fm_found=true
        break
      fi
      _fm_j=$((_fm_j + 1))
    done
    if [ "$_fm_found" = "false" ]; then
      _fm_l3_count=$((_fm_l3_count + 1))
      _fm_safe=$(printf '%s' "$_fm_l3" | sed "s/'/'\\\\''/g")
      eval "_fm_l3_$_fm_l3_count='$_fm_safe'"
    fi
    _fm_i=$((_fm_i + 1))
  done

  unset _fm_dsl _fm_i _fm_j _fm_raw _fm_safe _fm_line _fm_l1 _fm_l2 _fm_l3 _fm_found _fm_exist
}

# ---------------------------------------------------------------------------
# Section 3: flu_menu_get_children() — Get children of a menu path
# ---------------------------------------------------------------------------

# flu_menu_get_children <parent_path>
# Returns children of a parent path via stdout (newline-separated) and
# populates _fm_children_count + _fm_child_1..N for programmatic use.
# parent_path="" → returns Level 1 labels
# parent_path="Developer Tools" → returns Level 2 labels under that L1
# parent_path="Developer Tools|Languages" → returns Level 3 labels under that L1+L2
# Globals set: _fm_children_count, _fm_child_1..N
# shellcheck disable=SC2154  # eval-assigned variables
flu_menu_get_children() {
  _fm_parent=$1
  _fm_children_count=0

  if [ -z "$_fm_parent" ]; then
    # Level 1: return all unique L1 labels
    _fm_i=1
    while [ "$_fm_i" -le "$_fm_l1_count" ]; do
      eval "_fm_lab=\$_fm_l1_$_fm_i"
      _fm_children_count=$((_fm_children_count + 1))
      _fm_safe=$(printf '%s' "$_fm_lab" | sed "s/'/'\\\\''/g")
      eval "_fm_child_$_fm_children_count='$_fm_safe'"
      printf '%s\n' "$_fm_lab"
      _fm_i=$((_fm_i + 1))
    done
  else
    # Count pipe delimiters in parent to determine level
    _fm_depth=$(printf '%s' "$_fm_parent" | awk -F'|' '{print NF}')
    if [ "$_fm_depth" -eq 1 ]; then
      # Parent is L1, return L2 labels (unique within this L1)
      _fm_i=1
      while [ "$_fm_i" -le "$_fm_l2_count" ]; do
        eval "_fm_entry=\$_fm_l2_$_fm_i"
        _fm_entry_l1=$(printf '%s' "$_fm_entry" | awk -F'|' '{print $1}')
        if [ "$_fm_entry_l1" = "$_fm_parent" ]; then
          _fm_entry_l2=$(printf '%s' "$_fm_entry" | awk -F'|' '{print $2}')
          _fm_children_count=$((_fm_children_count + 1))
          _fm_safe=$(printf '%s' "$_fm_entry_l2" | sed "s/'/'\\\\''/g")
          eval "_fm_child_$_fm_children_count='$_fm_safe'"
          printf '%s\n' "$_fm_entry_l2"
        fi
        _fm_i=$((_fm_i + 1))
      done
    elif [ "$_fm_depth" -eq 2 ]; then
      # Parent is L1|L2, return L3 labels (unique within this L1+L2)
      _fm_i=1
      while [ "$_fm_i" -le "$_fm_l3_count" ]; do
        eval "_fm_entry=\$_fm_l3_$_fm_i"
        _fm_entry_prefix=$(printf '%s' "$_fm_entry" | awk -F'|' '{print $1 "|" $2}')
        if [ "$_fm_entry_prefix" = "$_fm_parent" ]; then
          _fm_entry_l3=$(printf '%s' "$_fm_entry" | awk -F'|' '{print $3}')
          _fm_children_count=$((_fm_children_count + 1))
          _fm_safe=$(printf '%s' "$_fm_entry_l3" | sed "s/'/'\\\\''/g")
          eval "_fm_child_$_fm_children_count='$_fm_safe'"
          printf '%s\n' "$_fm_entry_l3"
        fi
        _fm_i=$((_fm_i + 1))
      done
    fi
    # depth >= 3: no children (leaf level)
  fi

  unset _fm_parent _fm_i _fm_lab _fm_entry _fm_entry_l1 _fm_entry_l2 _fm_entry_l3 _fm_entry_prefix _fm_depth _fm_safe
}

# ---------------------------------------------------------------------------
# Section 4: flu_menu_is_leaf() — Check if path is a leaf node
# ---------------------------------------------------------------------------

# flu_menu_is_leaf <path>
# Returns 0 (true) if path is a leaf (has no children / is at max depth).
# Returns 1 (false) if path is an intermediate node (has children).
# Path is in the form "L1|L2" or "L1|L2|L3" or empty string.
flu_menu_is_leaf() {
  _fm_path=$1
  if [ -z "$_fm_path" ]; then
    # Root is never a leaf — always has children (Level 1 items)
    unset _fm_path
    return 1
  fi
  _fm_depth=$(printf '%s' "$_fm_path" | awk -F'|' '{print NF}')
  if [ "$_fm_depth" -ge 3 ]; then
    # Level 3 items are always leaves (max depth reached per MENU-01)
    unset _fm_path _fm_depth
    return 0
  fi
  # For depth 1 or 2, check if any children exist
  flu_menu_get_children "$_fm_path" >/dev/null
  if [ "$_fm_children_count" -eq 0 ]; then
    unset _fm_path _fm_depth
    return 0  # No children → leaf
  fi
  unset _fm_path _fm_depth
  return 1  # Has children → not leaf
}

# ---------------------------------------------------------------------------
# Section 5: flu_menu_get_breadcrumb() — Convert path to breadcrumb string
# ---------------------------------------------------------------------------

# flu_menu_get_breadcrumb <path>
# Converts a pipe-delimited path to " > " separated breadcrumb string.
# "Developer Tools|Languages" → "Main Menu > Developer Tools > Languages"
# Empty path → "Main Menu"
# Prints breadcrumb to stdout.
flu_menu_get_breadcrumb() {
  _fm_path=$1
  if [ -z "$_fm_path" ]; then
    printf 'Main Menu'
  else
    printf 'Main Menu'
    printf '%s' "$_fm_path" | awk -F'|' '{for(i=1;i<=NF;i++) printf " > %s", $i}'
  fi
  unset _fm_path
}

# ---------------------------------------------------------------------------
# Section 6: flu_menu_get_action() — Get action field for a full path
# ---------------------------------------------------------------------------

# flu_menu_get_action <full_path>
# Given a full 3-level path like "Developer Tools|Languages|Python",
# returns the action (4th field) from the matching DSL line.
# Prints action to stdout. If no match, prints empty string.
# shellcheck disable=SC2154  # eval-assigned variables
flu_menu_get_action() {
  _fm_path=$1
  _fm_i=1
  while [ "$_fm_i" -le "$_fm_count" ]; do
    eval "_fm_line=\$_fm_line_$_fm_i"
    _fm_prefix=$(printf '%s' "$_fm_line" | awk -F'|' '{print $1 "|" $2 "|" $3}')
    if [ "$_fm_prefix" = "$_fm_path" ]; then
      _fm_action=$(printf '%s' "$_fm_line" | awk -F'|' '{print $4}')
      printf '%s' "$_fm_action"
      unset _fm_path _fm_i _fm_line _fm_prefix _fm_action
      return 0
    fi
    _fm_i=$((_fm_i + 1))
  done
  # No match found
  unset _fm_path _fm_i _fm_line _fm_prefix
  return 1
}

# ---------------------------------------------------------------------------
# Section 7: _flu_menu_render() — Render current menu level
# ---------------------------------------------------------------------------

# Renders the current menu level with breadcrumb as title, numbered items
# with reverse-video highlight, scroll indicators, status row, and footer.
# Mirrors _tui_render_select() pattern using _fm_* state and _fr_* internals.
# shellcheck disable=SC2034,SC2154
_flu_menu_render() {
  clear_screen
  _fr_rows=$(tput lines 2>/dev/null || printf '24')
  _fr_cols=$(tput cols 2>/dev/null || printf '80')
  _fr_box_w=$((_fr_cols - 4))
  [ "$_fr_box_w" -lt 40 ] && _fr_box_w=40
  _fr_inner=$((_fr_box_w - 2))
  _fr_x=2
  _fr_r=1

  # Get breadcrumb for title
  _fr_breadcrumb=$(flu_menu_get_breadcrumb "$_fm_path")

  # === Top border with breadcrumb as title ===
  move_cursor "$_fr_r" "$_fr_x"
  printf '%s' "$TUI_BOX_TL"
  _fr_i=1; while [ "$_fr_i" -le "$_fr_inner" ]; do printf '%s' "$TUI_BOX_H"; _fr_i=$((_fr_i + 1)); done
  printf '%s' "$TUI_BOX_TR"
  _fr_r=$((_fr_r + 1))

  move_cursor "$_fr_r" "$_fr_x"
  printf '%s' "$TUI_BOX_V"
  _fr_tlen=${#_fr_breadcrumb}
  if [ "$_fr_tlen" -gt "$_fr_inner" ]; then _fr_tlen=$_fr_inner; fi
  _fr_tshow=$(printf '%s' "$_fr_breadcrumb" | awk -v L="$_fr_tlen" '{print substr($0,1,L)}')
  _fr_pad=$((_fr_inner - ${#_fr_tshow}))
  _fr_pl=$((_fr_pad / 2)); _fr_pr=$((_fr_pad - _fr_pl))
  _fr_j=0; while [ "$_fr_j" -lt "$_fr_pl" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
  printf '%s%s%s' "$TUI_BOLD" "$_fr_tshow" "$TUI_RESET"
  _fr_j=0; while [ "$_fr_j" -lt "$_fr_pr" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  _fr_r=$((_fr_r + 1))

  # === Separator row ===
  move_cursor "$_fr_r" "$_fr_x"
  printf '%s' "$TUI_BOX_V"
  _fr_i=1; while [ "$_fr_i" -le "$_fr_inner" ]; do printf '%s' "$TUI_BOX_H"; _fr_i=$((_fr_i + 1)); done
  printf '%s' "$TUI_BOX_V"
  _fr_r=$((_fr_r + 1))

  # === Calculate page size ===
  _fr_status_row=$((_fr_rows - 3))
  _fr_bottom_row=$((_fr_rows - 2))
  _fr_footer_row=$((_fr_rows - 1))
  _fm_page_size=$((_fr_status_row - _fr_r + 1))
  [ "$_fm_page_size" -lt 1 ] && _fm_page_size=1

  # === Scroll indicator (top) ===
  if [ "$_fm_scroll" -gt 1 ]; then
    move_cursor "$_fr_r" $((_fr_x + _fr_box_w - 9))
    printf '%s%cmore%s' "$TUI_DIM" '↑' "$TUI_RESET"
  fi

  # === Render visible items ===
  _fr_end=$((_fm_scroll + _fm_page_size - 1))
  [ "$_fr_end" -gt "$_fm_children_count" ] && _fr_end=$_fm_children_count
  _fr_maxlab=$((_fr_inner - 10))
  [ "$_fr_maxlab" -lt 5 ] && _fr_maxlab=5
  _fr_i=$_fm_scroll
  while [ "$_fr_i" -le "$_fr_end" ]; do
    # shellcheck disable=SC2086
    eval "_fr_lab=\$_fm_child_$_fr_i"
    if [ -z "$_fm_path" ]; then
      _fr_item_path="$_fr_lab"
    else
      _fr_item_path="${_fm_path}|${_fr_lab}"
    fi
    _fr_action=$(_flu_menu_lookup "$_fr_item_path") || true
    if [ -n "$_fr_action" ]; then
      if _flu_menu_queue_has "$_fr_action"; then
        _fr_chk="${TUI_GREEN}[x]${TUI_RESET} "
      else
        _fr_chk='[ ] '
      fi
    else
      _fr_chk='    '
    fi
    unset _fr_action
    # shellcheck disable=SC2154
    _fr_trunc=$(printf '%s' "$_fr_lab" | awk -v L="$_fr_maxlab" '{print substr($0,1,L)}')
    move_cursor "$_fr_r" "$_fr_x"
    printf '%s' "$TUI_BOX_V"
    if [ "$_fr_i" -eq "$_fm_cursor" ]; then
      printf '%s%s' "$TUI_REV" "$_fr_chk"
      printf '%s' "$TUI_RESET"
      printf '%s%3d) %s' "$TUI_REV" "$_fr_i" "$_fr_trunc"
      _fr_used=$((10 + ${#_fr_trunc}))
      _fr_fill=$((_fr_inner - _fr_used))
      [ "$_fr_fill" -gt 0 ] && _fr_j=0 && while [ "$_fr_j" -lt "$_fr_fill" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
      printf '%s' "$TUI_RESET"
    else
      printf '%s%3d) %s%s' "$_fr_chk" "$_fr_i" "$_fr_trunc"
      _fr_used=$((10 + ${#_fr_trunc}))
      _fr_fill=$((_fr_inner - _fr_used))
      [ "$_fr_fill" -gt 0 ] && _fr_j=0 && while [ "$_fr_j" -lt "$_fr_fill" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
    fi
    printf '%s' "$TUI_BOX_V"
    _fr_r=$((_fr_r + 1))
    _fr_i=$((_fr_i + 1))
    unset _fr_item_path _fr_chk
  done

  # === Fill remaining body rows with empty space ===
  while [ "$_fr_r" -le "$_fr_status_row" ]; do
    move_cursor "$_fr_r" "$_fr_x"
    printf '%s' "$TUI_BOX_V"
    _fr_j=0; while [ "$_fr_j" -lt "$_fr_inner" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
    printf '%s' "$TUI_BOX_V"
    _fr_r=$((_fr_r + 1))
  done

  # === Scroll indicator (bottom) ===
  if [ "$_fr_end" -lt "$_fm_children_count" ]; then
    _fr_drow=$((_fr_r - 1))
    move_cursor "$_fr_drow" $((_fr_x + _fr_box_w - 9))
    printf '%s%cmore%s' "$TUI_DIM" '↓' "$TUI_RESET"
  fi

  # === Status row ===
  move_cursor "$_fr_status_row" "$_fr_x"
  printf '%s' "$TUI_BOX_V"
  _fr_j=0; while [ "$_fr_j" -lt "$_fr_inner" ]; do printf ' '; _fr_j=$((_fr_j + 1)); done
  printf '%s' "$TUI_BOX_V"
  move_cursor "$_fr_status_row" $((_fr_x + 2))
  if [ -n "$_fm_error_msg" ]; then
    printf '%s%s%s' "$TUI_RED" "$_fm_error_msg" "$TUI_RESET"
  else
    printf 'Item %d of %d' "$_fm_cursor" "$_fm_children_count"
  fi

  # === Bottom border ===
  move_cursor "$_fr_bottom_row" "$_fr_x"
  printf '%s' "$TUI_BOX_BL"
  _fr_i=1; while [ "$_fr_i" -le "$_fr_inner" ]; do printf '%s' "$TUI_BOX_H"; _fr_i=$((_fr_i + 1)); done
  printf '%s' "$TUI_BOX_BR"

  # === Footer row ===
  move_cursor "$_fr_footer_row" "$_fr_x"
  _fr_qc=$(_flu_menu_queue_count)
  if [ "$_fm_show_help" = "true" ]; then
    _fr_ft='Up/Dn Move  Space Toggle  Enter Run  Esc/← Back  PgUp/PgDn  Home/End  j/k Vi  ? Keys'
  else
    _fr_ft='Up/Dn  Space Toggle  Enter Run  Esc Back  ? Keys'
  fi
  if [ "$_fr_qc" -gt 0 ]; then
    _fr_ft="$_fr_ft  ${TUI_GREEN}${_fr_qc} selected${TUI_RESET}"
  fi
  printf '%s%s%s' "$TUI_DIM" "$_fr_ft" "$TUI_RESET"

  printf '%s[?25l' "$ESC"

  # Cleanup all _fr_* variables
  unset _fr_rows _fr_cols _fr_box_w _fr_inner _fr_x _fr_r _fr_i _fr_j
  unset _fr_tlen _fr_tshow _fr_pad _fr_pl _fr_pr
  unset _fr_status_row _fr_bottom_row _fr_footer_row _fr_end _fr_maxlab
  unset _fr_lab _fr_trunc _fr_used _fr_fill _fr_drow _fr_ft
  unset _fr_breadcrumb
}

# ---------------------------------------------------------------------------
# Section 8: flu_menu_navigate() — Hierarchical menu navigation
# ---------------------------------------------------------------------------

# flu_menu_navigate <dsl_file>
# Navigates a 3-level hierarchical menu defined by the DSL file.
# Uses tui.sh primitives for TUI rendering (when available) or
# numbered fallback prompts (when TERM=dumb or no TTY).
#
# Returns:
#   Exit 0: Prints "L1|L2|L3|action" to stdout, sets TUI_RESULT
#   Exit 1: User cancelled at root level
_flu_menu_queue_has() {
  case " $_fm_queue " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

_flu_menu_queue_add() {
  if _flu_menu_queue_has "$1"; then
    _fmq_tmp=""
    for _fmq_i in $_fm_queue; do
      [ "$_fmq_i" = "$1" ] && continue
      _fmq_tmp="$_fmq_tmp $_fmq_i"
    done
    _fm_queue="${_fmq_tmp# }"
  else
    if [ -z "$_fm_queue" ]; then
      _fm_queue="$1"
    else
      _fm_queue="$_fm_queue $1"
    fi
  fi
  unset _fmq_tmp _fmq_i
}

_flu_menu_queue_count() {
  if [ -z "$_fm_queue" ]; then
    printf '0'
  else
    printf '%s\n' "$_fm_queue" | wc -w | awk '{print $1}'
  fi
}

_flu_menu_lookup() {
  _fmlu_path=$1
  _fmlu_i=1
  while [ "$_fmlu_i" -le "$_fm_count" ]; do
    eval "_fmlu_line=\$_fm_line_$_fmlu_i"
    _fmlu_pfx=$(printf '%s' "$_fmlu_line" | awk -F'|' '{print $1 "|" $2 "|" $3}')
    if [ "$_fmlu_pfx" = "$_fmlu_path" ]; then
      printf '%s' "$_fmlu_line" | awk -F'|' '{print $4}'
      unset _fmlu_path _fmlu_i _fmlu_line _fmlu_pfx
      return 0
    fi
    _fmlu_i=$((_fmlu_i + 1))
  done
  unset _fmlu_path _fmlu_i _fmlu_line _fmlu_pfx
  return 1
}

_flu_menu_queue_add() {
  if _flu_menu_queue_has "$1"; then
    _fm_q_tmp=""
    for _fm_q_i in $_fm_queue; do
      [ "$_fm_q_i" = "$1" ] && continue
      _fm_q_tmp="$_fm_q_tmp $_fm_q_i"
    done
    _fm_queue="${_fm_q_tmp# }"
  else
    if [ -z "$_fm_queue" ]; then
      _fm_queue="$1"
    else
      _fm_queue="$_fm_queue $1"
    fi
  fi
  unset _fm_q_tmp _fm_q_i
}

_flu_menu_queue_count() {
  if [ -z "$_fm_queue" ]; then
    printf '0'
  else
    printf '%s\n' "$_fm_queue" | wc -w | awk '{print $1}'
  fi
}

# shellcheck disable=SC2034,SC2154
flu_menu_navigate() {
  _fm_dsl_file=$1
  flu_menu_load "$_fm_dsl_file" || return 1

  _fm_path=""
  _fm_cursor=1
  _fm_scroll=1
  _fm_show_help=false
  _fm_error_msg=''
  _fm_page_size=1
  _fm_queue=""

  # --- Non-TTY fallback ---
  if [ "$_tui_use_tui" = "false" ]; then
    _flu_menu_navigate_fallback
    _fm_fb_rc=$?
    unset _fm_dsl_file _fm_path _fm_cursor _fm_scroll _fm_show_help _fm_error_msg _fm_page_size
    unset _fm_queue
    return $_fm_fb_rc
  fi

  # --- TUI navigation ---
  tui_init

  while :; do
    # Get children for current path
    flu_menu_get_children "$_fm_path"

    if [ "$_fm_children_count" -eq 0 ]; then
      tui_restore
      printf 'Error: No menu items at path: %s\n' "$_fm_path" >&2
      unset _fm_path _fm_cursor _fm_scroll _fm_show_help _fm_error_msg _fm_page_size
      unset _fm_dsl_file _fm_key _fm_bottom _fm_max_scroll _fm_new_path _fm_selected
      unset _fm_queue
      TUI_QUEUE=""
      return 1
    fi

    # Ensure cursor is within bounds
    [ "$_fm_cursor" -gt "$_fm_children_count" ] && _fm_cursor=$_fm_children_count
    [ "$_fm_cursor" -lt 1 ] && _fm_cursor=1

    # Render current level
    _flu_menu_render

    # Read key
    _tui_read_key
    _fm_key="$_tui_rk_result"

    # --- Navigation dispatch ---
    case "$_fm_key" in
      "$TUI_KEY_UP")
        if [ "$_fm_cursor" -gt 1 ]; then
          _fm_cursor=$((_fm_cursor - 1))
          if [ "$_fm_cursor" -lt "$_fm_scroll" ]; then
            _fm_scroll=$((_fm_scroll - 1))
          fi
        fi
        _fm_error_msg=''
        ;;
      "$TUI_KEY_DOWN")
        if [ "$_fm_cursor" -lt "$_fm_children_count" ]; then
          _fm_cursor=$((_fm_cursor + 1))
          _fm_bottom=$((_fm_scroll + _fm_page_size - 1))
          if [ "$_fm_cursor" -gt "$_fm_bottom" ]; then
            _fm_scroll=$((_fm_scroll + 1))
          fi
        fi
        _fm_error_msg=''
        ;;
      "$TUI_KEY_PGUP")
        _fm_scroll=$((_fm_scroll - _fm_page_size))
        [ "$_fm_scroll" -lt 1 ] && _fm_scroll=1
        _fm_cursor=$_fm_scroll
        _fm_error_msg=''
        ;;
      "$TUI_KEY_PGDN")
        _fm_scroll=$((_fm_scroll + _fm_page_size))
        _fm_max_scroll=$((_fm_children_count - _fm_page_size + 1))
        [ "$_fm_max_scroll" -lt 1 ] && _fm_max_scroll=1
        [ "$_fm_scroll" -gt "$_fm_max_scroll" ] && _fm_scroll=$_fm_max_scroll
        _fm_bottom=$((_fm_scroll + _fm_page_size - 1))
        [ "$_fm_bottom" -gt "$_fm_children_count" ] && _fm_bottom=$_fm_children_count
        _fm_cursor=$_fm_bottom
        _fm_error_msg=''
        ;;
      "$TUI_KEY_HOME")
        _fm_cursor=1; _fm_scroll=1; _fm_error_msg=''
        ;;
      "$TUI_KEY_END")
        _fm_cursor=$_fm_children_count
        _fm_max_scroll=$((_fm_children_count - _fm_page_size + 1))
        [ "$_fm_max_scroll" -lt 1 ] && _fm_max_scroll=1
        _fm_scroll=$_fm_max_scroll
        _fm_error_msg=''
        ;;
      "$TUI_KEY_SPACE")
        eval "_fm_selected=\$_fm_child_$_fm_cursor"
        if [ -z "$_fm_path" ]; then
          _fm_new_path="$_fm_selected"
        else
          _fm_new_path="${_fm_path}|${_fm_selected}"
        fi
        _fm_space_action=$(_flu_menu_lookup "$_fm_new_path") || true
        if [ -n "$_fm_space_action" ]; then
          _flu_menu_queue_add "$_fm_space_action"
        fi
        unset _fm_space_action _fm_new_path
        ;;
      "$TUI_KEY_ENTER")
        if [ -n "$_fm_queue" ]; then
          tui_restore
          TUI_RESULT=""
          TUI_QUEUE="$_fm_queue"
          unset _fm_path _fm_cursor _fm_scroll _fm_show_help _fm_error_msg
          unset _fm_page_size _fm_dsl_file _fm_key _fm_bottom _fm_max_scroll
          unset _fm_new_path _fm_selected _fm_queue
          return 0
        fi

        eval "_fm_selected=\$_fm_child_$_fm_cursor"
        if [ -z "$_fm_path" ]; then
          _fm_new_path="$_fm_selected"
        else
          _fm_new_path="${_fm_path}|${_fm_selected}"
        fi

        if flu_menu_is_leaf "$_fm_new_path"; then
          tui_restore
          TUI_RESULT="$_fm_new_path"
          TUI_QUEUE=""
          unset _fm_path _fm_new_path _fm_selected _fm_cursor _fm_scroll
          unset _fm_show_help _fm_error_msg _fm_page_size _fm_dsl_file
          unset _fm_key _fm_bottom _fm_max_scroll _fm_queue
          return 0
        fi

        # Not leaf — descend into submenu
        _fm_path="$_fm_new_path"
        _fm_cursor=1
        _fm_scroll=1
        _fm_error_msg=''
        ;;

      "$TUI_KEY_ESC"|"$TUI_KEY_Q")
        # Check for missed ESC [ D / C patterns — _tui_read_key already
        # decodes them to TUI_KEY_LEFT/TUI_KEY_RIGHT but timing can yield
        # plain ESC before the full sequence arrives
        _flu_menu_esc_result=''
        stty min 0 time 1 2>/dev/null || true
        _flu_menu_b1=$(dd bs=1 count=1 2>/dev/null </dev/tty | od -A n -t d1 | awk '{print $1}')
        if [ "${_flu_menu_b1:-}" = "91" ]; then
          _flu_menu_b2=$(dd bs=1 count=1 2>/dev/null </dev/tty | od -A n -t d1 | awk '{print $1}')
          if [ "${_flu_menu_b2:-}" = "68" ]; then
            _flu_menu_esc_result='left'
          elif [ "${_flu_menu_b2:-}" = "67" ]; then
            _flu_menu_esc_result='right'
          fi
        fi
        # Restore terminal to raw mode before any further key reads
        stty -echo -icanon min 1 time 0 2>/dev/null || true

        if [ "$_flu_menu_esc_result" = "right" ]; then
          eval "_fm_selected=\$_fm_child_$_fm_cursor"
          if [ -z "$_fm_path" ]; then
            _fm_new_path="$_fm_selected"
          else
            _fm_new_path="${_fm_path}|${_fm_selected}"
          fi
          if flu_menu_is_leaf "$_fm_new_path"; then
            tui_restore
            TUI_RESULT="$_fm_new_path"
            TUI_QUEUE=""
            unset _fm_path _fm_new_path _fm_selected _fm_cursor _fm_scroll
            unset _fm_show_help _fm_error_msg _fm_page_size _fm_dsl_file
            unset _fm_key _fm_bottom _fm_max_scroll _fm_queue
            unset _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2
            return 0
          fi
          _fm_path="$_fm_new_path"
          _fm_cursor=1
          _fm_scroll=1
          _fm_error_msg=''
          unset _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2 2>/dev/null
          continue
        fi

        if [ "$_flu_menu_esc_result" = "left" ]; then
          if [ -z "$_fm_path" ]; then
            # At root: Left arrow is a no-op (don't exit)
            _fm_error_msg=''
            continue
          fi
          _fm_path=$(printf '%s' "$_fm_path" | awk -F'|' '{for(i=1;i<NF;i++) printf "%s%s", (i>1?"|":""), $i}')
          _fm_cursor=1
          _fm_scroll=1
          _fm_error_msg=''
          continue
        fi

        if [ -z "$_fm_path" ]; then
          tui_restore
          TUI_RESULT=''
          TUI_QUEUE=""
          unset _fm_path _fm_cursor _fm_scroll _fm_show_help _fm_error_msg _fm_page_size
          unset _fm_dsl_file _fm_key _fm_bottom _fm_max_scroll _fm_new_path _fm_selected
          unset _fm_queue _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2
          return 1
        fi
        _fm_path=$(printf '%s' "$_fm_path" | awk -F'|' '{for(i=1;i<NF;i++) printf "%s%s", (i>1?"|":""), $i}')
        _fm_cursor=1
        _fm_scroll=1
        _fm_error_msg=''
        ;;

      "$TUI_KEY_LEFT")
        if [ -z "$_fm_path" ]; then
          continue
        fi
        _fm_path=$(printf '%s' "$_fm_path" | awk -F'|' '{for(i=1;i<NF;i++) printf "%s%s", (i>1?"|":""), $i}')
        _fm_cursor=1
        _fm_scroll=1
        _fm_error_msg=''
        ;;

      "$TUI_KEY_HELP")
        if [ "$_fm_show_help" = "true" ]; then
          _fm_show_help=false
        else
          _fm_show_help=true
        fi
        ;;
    esac

    unset _flu_menu_esc_result _flu_menu_b1 _flu_menu_b2 2>/dev/null
  done
}

# ---------------------------------------------------------------------------
# Section 9: _flu_menu_navigate_fallback() — Non-TTY fallback navigation
# ---------------------------------------------------------------------------

# Provides the same 3-level hierarchical navigation using numbered text
# prompts when TERM=dumb or no TTY is available. Called automatically by
# flu_menu_navigate() when _tui_use_tui is "false".
# shellcheck disable=SC2034
_flu_menu_navigate_fallback() {
  _fm_path=""

  while :; do
    flu_menu_get_children "$_fm_path"
    _fm_breadcrumb=$(flu_menu_get_breadcrumb "$_fm_path")

    printf '\n'
    printf '%s\n' "$_fm_breadcrumb"
    printf '%s\n' "----------------------------------------"

    _fm_i=1
    while [ "$_fm_i" -le "$_fm_children_count" ]; do
      # shellcheck disable=SC2086
      eval "printf ' %2d) %s\n' \"$_fm_i\" \"\$_fm_child_$_fm_i\""
      _fm_i=$((_fm_i + 1))
    done

    if [ -n "$_fm_path" ]; then
      printf '  0) Back\n'
    else
      printf '  0) Exit\n'
    fi

    printf '> '
    IFS= read -r _fm_choice || { printf '\n'; unset _fm_path _fm_breadcrumb _fm_i; return 1; }

    case "$_fm_choice" in
      0)
        if [ -z "$_fm_path" ]; then
          # Exit at root
          TUI_RESULT=''
          unset _fm_path _fm_breadcrumb _fm_i _fm_choice
          return 1
        fi
        # Go up one level — strip last pipe segment
        _fm_path=$(printf '%s' "$_fm_path" | awk -F'|' '{for(i=1;i<NF;i++) printf "%s%s", (i>1?"|":""), $i}')
        ;;

      *)
        # Validate numeric input
        _fm_choice_num=$(printf '%s' "$_fm_choice" | awk '{print $1 + 0}')
        if [ "${_fm_choice_num:-0}" -ge 1 ] 2>/dev/null && \
           [ "${_fm_choice_num:-0}" -le "$_fm_children_count" ] 2>/dev/null; then
          # shellcheck disable=SC2086
          eval "_fm_selected=\$_fm_child_$_fm_choice_num"

          if [ -z "$_fm_path" ]; then
            _fm_new_path="$_fm_selected"
          else
            _fm_new_path="${_fm_path}|${_fm_selected}"
          fi

          if flu_menu_is_leaf "$_fm_new_path"; then
            TUI_RESULT="$_fm_new_path"
            unset _fm_path _fm_new_path _fm_selected _fm_breadcrumb _fm_i _fm_choice _fm_choice_num
            return 0
          fi

          # Descend into submenu
          _fm_path="$_fm_new_path"
        else
          printf 'Invalid choice: %s\n' "$_fm_choice" >&2
        fi
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Section 10: Demo mode
# ---------------------------------------------------------------------------

# Only execute demo when run directly (not when sourced)
case "${0##*/}" in
  menu.sh|menu)
    if [ "${1:-}" = "--demo" ] || [ "${1:-}" = "--demo-menu" ]; then
      echo "flu.sh Menu Demo"
      echo "================"
      echo ""
      echo "Navigating menu.db..."
      echo ""

      # Source tui.sh relative to menu.sh location
      _menu_dir=$(cd "$(dirname "$0")" && pwd)
      # shellcheck disable=SC1091
      . "$_menu_dir/tui.sh"
      unset _menu_dir

      flu_menu_navigate "menu.db"
      _demo_rc=$?

      echo ""
      if [ "$_demo_rc" -eq 0 ]; then
        echo "Selected: $TUI_RESULT"
      else
        echo "Cancelled."
      fi
      unset _demo_rc
    fi
    ;;
esac
