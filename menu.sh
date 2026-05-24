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
