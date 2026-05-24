#!/usr/bin/env sh
# modules.sh — Module architecture library for flu.sh
#
# Module fetch engine and metadata parser. Fetches modular install
# scripts from GitHub on demand, parses comment-header metadata,
# and provides parameter declaration parsing.
#
# Usage:
#   . ./tui.sh
#   . ./modules.sh
#   flu_module_resolve_url "install_python"
#   flu_module_fetch "install_python"
#   flu_module_fetch "install_python" | flu_module_parse_metadata
#
# No external dependencies. No bashisms. Every line passes shellcheck -s sh.
#
# shellcheck disable=SC2034  # Library constants are used by callers who source this file
# shellcheck disable=SC2154  # eval-assigned variables used by callers

# ---------------------------------------------------------------------------
# Section 1: Source tui.sh if not already sourced
# ---------------------------------------------------------------------------

if [ -z "${TUI_RESET:-}" ]; then
  _mod_script_dir=$(cd "$(dirname "$0")" && pwd)
  # shellcheck disable=SC1091
  . "$_mod_script_dir/tui.sh"
  unset _mod_script_dir
fi

# ---------------------------------------------------------------------------
# Section 2: flu_module_resolve_url() — Action ID to GitHub URL
# ---------------------------------------------------------------------------

# flu_module_resolve_url <action_id>
# Resolves an action identifier (from flu_menu_get_action) to a
# GitHub raw URL for the module script.
# Override base URL via FLU_MODULES_BASE_URL env var.
# Prints the full URL to stdout. Returns 0 on success.
flu_module_resolve_url() {
  _fmr_action="$1"
  _fmr_base="${FLU_MODULES_BASE_URL:-https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/}"
  printf '%s%s.sh\n' "$_fmr_base" "$_fmr_action"
  unset _fmr_action _fmr_base
  return 0
}

# ---------------------------------------------------------------------------
# Section 3: flu_module_fetch() — Fetch module script from GitHub
# ---------------------------------------------------------------------------

# flu_module_fetch <action_id>
# Fetches a module script from GitHub using curl (or wget fallback).
# Retries up to 3 times with 2-second delay on failure.
# Outputs script content to stdout on success.
# Prints actionable error messages to stderr on failure.
# Returns 0 on success, 1 on failure.
flu_module_fetch() {
  _fmf_action="$1"
  _fmf_url=$(flu_module_resolve_url "$_fmf_action")
  _fmf_attempt=1

  while [ "$_fmf_attempt" -le 3 ]; do
    if command -v curl >/dev/null 2>&1; then
      _fmf_content=$(curl -fsSL --connect-timeout 10 "$_fmf_url" 2>/dev/null)
      _fmf_rc=$?
    else
      _fmf_content=$(wget -qO- --timeout=10 "$_fmf_url" 2>/dev/null)
      _fmf_rc=$?
    fi

    if [ "$_fmf_rc" -eq 0 ]; then
      printf '%s\n' "$_fmf_content"
      unset _fmf_action _fmf_url _fmf_attempt _fmf_rc _fmf_content
      return 0
    fi

    if [ "$_fmf_attempt" -lt 3 ]; then
      sleep 2
    fi
    _fmf_attempt=$((_fmf_attempt + 1))
  done

  # All retries exhausted — report error to stderr
  printf '%s[ERROR]%s Failed to fetch module: %s (exit: %d)\n' \
    "$TUI_RED" "$TUI_RESET" "$_fmf_url" "$_fmf_rc" >&2
  case "$_fmf_rc" in
    6|7|28)
      printf '%s [HINT]%s  Check internet connection\n' \
        "$TUI_YELLOW" "$TUI_RESET" >&2
      ;;
    22)
      printf '%s [HINT]%s  Module not found — might be renamed\n' \
        "$TUI_YELLOW" "$TUI_RESET" >&2
      ;;
    *)
      printf '%s [HINT]%s  Unknown network error\n' \
        "$TUI_YELLOW" "$TUI_RESET" >&2
      ;;
  esac

  unset _fmf_action _fmf_url _fmf_attempt _fmf_rc _fmf_content
  return 1
}

# ---------------------------------------------------------------------------
# Section 4: flu_module_parse_metadata() — Parse module comment header
# ---------------------------------------------------------------------------

# flu_module_parse_metadata
# Reads module script content from stdin and parses @key: value
# metadata from the comment header block (D-01, D-02).
# Header terminates at first blank line or first non-comment line.
#
# Extracts: @name, @params, @platforms, @version, @deps, @timeout
# Required: @name, @platforms, @version — missing → error + return 1
# Defaults:  @timeout=300, @params='', @deps=''
#
# Validates current OS against @platforms list.
# Outputs 6 fields to stdout (one per line): name params platforms version deps timeout
# Sets globals: _fmp_name, _fmp_params, _fmp_platforms, _fmp_version,
#                _fmp_deps, _fmp_timeout
# Returns 0 on success, 1 on parse failure or platform mismatch.
flu_module_parse_metadata() {
  # Parse stdin with awk — extract @key: value fields from comment header
  _fmp_out=$(awk '
    /^$/ { exit 0 }
    !/^#/ { exit 0 }
    /^# @name:/ { gsub(/^# @name: */, ""); name=$0 }
    /^# @params:/ { gsub(/^# @params: */, ""); params=$0 }
    /^# @platforms:/ { gsub(/^# @platforms: */, ""); platforms=$0 }
    /^# @version:/ { gsub(/^# @version: */, ""); version=$0 }
    /^# @deps:/ { gsub(/^# @deps: */, ""); deps=$0 }
    /^# @timeout:/ { gsub(/^# @timeout: */, ""); timeout=$0 }
    END {
      printf "%s\n%s\n%s\n%s\n%s\n%s\n", name, params, platforms, version, deps, timeout
    }
  ')

  # Extract individual fields from awk output (6 lines, may be empty)
  _fmp_name=$(printf '%s\n' "$_fmp_out" | awk 'NR==1')
  _fmp_params=$(printf '%s\n' "$_fmp_out" | awk 'NR==2')
  _fmp_platforms=$(printf '%s\n' "$_fmp_out" | awk 'NR==3')
  _fmp_version=$(printf '%s\n' "$_fmp_out" | awk 'NR==4')
  _fmp_deps=$(printf '%s\n' "$_fmp_out" | awk 'NR==5')
  _fmp_timeout=$(printf '%s\n' "$_fmp_out" | awk 'NR==6')

  # Apply default timeout if empty
  [ -z "$_fmp_timeout" ] && _fmp_timeout='300'

  # Validate required fields
  if [ -z "$_fmp_name" ]; then
    printf '%s[ERROR]%s Module missing required @name field\n' \
      "$TUI_RED" "$TUI_RESET" >&2
    unset _fmp_out _fmp_name _fmp_params _fmp_platforms _fmp_version _fmp_deps _fmp_timeout
    return 1
  fi
  if [ -z "$_fmp_platforms" ]; then
    printf '%s[ERROR]%s Module missing required @platforms field\n' \
      "$TUI_RED" "$TUI_RESET" >&2
    unset _fmp_out _fmp_name _fmp_params _fmp_platforms _fmp_version _fmp_deps _fmp_timeout
    return 1
  fi
  if [ -z "$_fmp_version" ]; then
    printf '%s[ERROR]%s Module missing required @version field\n' \
      "$TUI_RED" "$TUI_RESET" >&2
    unset _fmp_out _fmp_name _fmp_params _fmp_platforms _fmp_version _fmp_deps _fmp_timeout
    return 1
  fi

  # Platform validation — map uname to short names and check @platforms list
  _fmp_os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$_fmp_os" in
    linux*) _fmp_os="linux" ;;
    darwin*) _fmp_os="darwin" ;;
  esac

  _fmp_plat_match=false
  _fmp_saved_ifs="$IFS"
  IFS=','
  for _fmp_p in $_fmp_platforms; do
    # Trim whitespace from platform name
    _fmp_p=$(printf '%s' "$_fmp_p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ "$_fmp_p" = "$_fmp_os" ]; then
      _fmp_plat_match=true
      break
    fi
  done
  IFS="$_fmp_saved_ifs"

  if [ "$_fmp_plat_match" = "false" ]; then
    printf '%s[ERROR]%s Module not available for this platform (%s)\n' \
      "$TUI_RED" "$TUI_RESET" "$_fmp_os" >&2
    unset _fmp_out _fmp_os _fmp_saved_ifs _fmp_p _fmp_plat_match
    unset _fmp_name _fmp_params _fmp_platforms _fmp_version _fmp_deps _fmp_timeout
    return 1
  fi

  # Output parsed metadata to stdout — one field per line
  printf '%s\n' "$_fmp_name"
  printf '%s\n' "$_fmp_params"
  printf '%s\n' "$_fmp_platforms"
  printf '%s\n' "$_fmp_version"
  printf '%s\n' "$_fmp_deps"
  printf '%s\n' "$_fmp_timeout"

  # Cleanup internal temporaries but keep _fmp_* globals for caller use
  unset _fmp_out _fmp_os _fmp_saved_ifs _fmp_p _fmp_plat_match
  return 0
}

# ---------------------------------------------------------------------------
# Section 5: _flu_parse_params() — Parse parameter declarations
# ---------------------------------------------------------------------------

# _flu_parse_params <param_string>
# Parses semicolon-delimited parameter declarations (D-03 format).
# Input: "name=type:choice1,choice2;name2=type:choice1,choice2"
# Output: newline-separated rows: "index|name|type|choices"
#
# Empty input returns 0 (no params is valid).
# Input missing '=' separator returns 1 (invalid format).
# Supported types: radio, text, yesno. Default type: text.
_flu_parse_params() {
  _fpp_input="$1"

  # Empty input — valid, no parameters
  if [ -z "$_fpp_input" ]; then
    unset _fpp_input
    return 0
  fi

  # Validate: must contain at least one '=' separator
  case "$_fpp_input" in
    *"="*) ;;
    *)
      printf '%s[ERROR]%s Invalid param format: missing "=" separator\n' \
        "$TUI_RED" "$TUI_RESET" >&2
      unset _fpp_input
      return 1
      ;;
  esac

  # Parse semicolon-delimited declarations with awk
  printf '%s' "$_fpp_input" | awk -F';' '{
    idx = 0
    for (i = 1; i <= NF; i++) {
      if ($i == "") continue
      split($i, a, "=")
      name = a[1]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == "") continue

      type_spec = (length(a) > 1 ? a[2] : "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", type_spec)

      if (index(type_spec, ":") > 0) {
        split(type_spec, b, ":")
        type = b[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", type)
        choices = b[2]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", choices)
      } else {
        type = (type_spec != "" ? type_spec : "text")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", type)
        choices = ""
      }
      if (type == "") type = "text"
      printf "%d|%s|%s|%s\n", idx, name, type, choices
      idx++
    }
  }'

  _fpp_rc=$?
  unset _fpp_input
  return $_fpp_rc
}
