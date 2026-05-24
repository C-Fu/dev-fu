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

# ---------------------------------------------------------------------------
# Section 6: flu_module_set_env() — Platform context detection
# ---------------------------------------------------------------------------

# _flu_detect_pkg_mgr
# Detects the available package manager on the system.
# Checks in priority order: apt-get, apk, dnf, pacman, zypper, brew.
# Prints package manager name to stdout. Returns 0 always.
_flu_detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt\n'; return 0
  fi
  if command -v apk >/dev/null 2>&1; then
    printf 'apk\n'; return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    printf 'dnf\n'; return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    printf 'pacman\n'; return 0
  fi
  if command -v zypper >/dev/null 2>&1; then
    printf 'zypper\n'; return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    printf 'brew\n'; return 0
  fi
  printf 'unknown\n'; return 0
}

# flu_module_set_env
# Detects platform context and exports FLU_* environment variables
# for module scripts. Sets all 7 variables: FLU_OS, FLU_DISTRO,
# FLU_PKG_MGR, FLU_ARCH, FLU_IS_WSL, FLU_IS_TERMUX, FLU_IS_ROOT.
# Pattern adapted from fu.sh detect_platform()/detect_distro()
# rewritten in POSIX sh (D-11).
flu_module_set_env() {
  # FLU_OS: detect via uname (darwin/linux)
  _fse_os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$_fse_os" in
    darwin*) FLU_OS="darwin" ;;
    linux*)  FLU_OS="linux" ;;
    *)       FLU_OS="linux" ;;
  esac

  # FLU_DISTRO: parse /etc/os-release for ID field
  if [ -f /etc/os-release ]; then
    FLU_DISTRO=$(
      # shellcheck disable=SC1091
      . /etc/os-release 2>/dev/null && printf '%s' "${ID:-linux}"
    )
  else
    FLU_DISTRO="linux"
  fi

  # FLU_PKG_MGR: detect available package manager
  FLU_PKG_MGR=$(_flu_detect_pkg_mgr)

  # FLU_ARCH: CPU architecture string
  FLU_ARCH=$(uname -m)

  # FLU_IS_WSL: check /proc/version for Microsoft signature
  if grep -qi "microsoft" /proc/version 2>/dev/null; then
    FLU_IS_WSL="1"
  else
    FLU_IS_WSL="0"
  fi

  # FLU_IS_TERMUX: check env var and standard Termux directory
  if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ]; then
    FLU_IS_TERMUX="1"
  else
    FLU_IS_TERMUX="0"
  fi

  # FLU_IS_ROOT: check effective UID
  if [ "$(id -u)" -eq 0 ]; then
    FLU_IS_ROOT="1"
  else
    FLU_IS_ROOT="0"
  fi

  # Export all 7 platform context variables to module environment
  export FLU_OS FLU_DISTRO FLU_PKG_MGR FLU_ARCH
  export FLU_IS_WSL FLU_IS_TERMUX FLU_IS_ROOT

  unset _fse_os
}

# ---------------------------------------------------------------------------
# Section 7: flu_module_collect_params() — Parameter collection via TUI widgets
# ---------------------------------------------------------------------------

# flu_module_collect_params <param_string>
# Parses @params declarations and prompts the user for each parameter
# using the appropriate Phase 2 TUI widget (D-10).
#
# Parameter types:
#   radio  → tui_radio()  — single-select from comma-separated choices
#   text   → tui_text_input() — freeform text entry
#   yesno  → tui_yesno()  — boolean confirmation
#
# Collected values are accumulated as --key value pairs in the
# global _flu_module_args variable for the executor to consume.
#
# Returns 0 after all params collected, 1 if user cancelled (Esc).
_flu_module_args=''
flu_module_collect_params() {
  _fc_param_string="$1"

  # Guard: verify tui.sh has been sourced (check for TUI_RESET constant)
  if [ -z "${TUI_RESET:-}" ]; then
    printf '%s[ERROR]%s tui.sh must be sourced before calling flu_module_collect_params\n' \
      "$TUI_RED" "$TUI_RESET" >&2
    return 1
  fi

  _flu_module_args=''

  # Empty params — no collection needed, valid state
  if [ -z "$_fc_param_string" ]; then
    unset _fc_param_string
    return 0
  fi

  # Parse the parameter string into index|name|type|choices rows
  _fc_parsed=$(_flu_parse_params "$_fc_param_string")
  _fc_parse_rc=$?
  if [ "$_fc_parse_rc" -ne 0 ]; then
    unset _fc_param_string _fc_parse_rc _fc_parsed
    return 1
  fi

  # Write parsed rows to temp file to avoid subshell issues
  # with pipe (while ... | read creates subshell in POSIX sh).
  _fc_tmp="/tmp/flu_collect_$$"
  printf '%s\n' "$_fc_parsed" > "$_fc_tmp"

  while IFS='|' read -r _fc_idx _fc_name _fc_type _fc_choices; do
    [ -z "$_fc_name" ] && continue

    case "$_fc_type" in
      radio)
        # Count choices and store them for later index lookup
        _fc_count=0
        _fc_saved_ifs="$IFS"
        IFS=','
        for _fc_ch in $_fc_choices; do
          _fc_count=$((_fc_count + 1))
        done
        IFS="$_fc_saved_ifs"

        if [ "$_fc_count" -eq 0 ]; then
          continue
        fi

        # Build eval-safe tui_radio call with all choices as positional args.
        # Pattern: sed "s/'/'\\\\''/g" for safe eval (established in tui.sh).
        _fc_eval="tui_radio \"\$_fc_name\" \"Select \$_fc_name\""
        _fc_saved_ifs="$IFS"
        IFS=','
        for _fc_ch in $_fc_choices; do
          _fc_safe=$(printf '%s' "$_fc_ch" | sed "s/'/'\\\\''/g")
          _fc_eval="$_fc_eval '$_fc_safe'"
        done
        IFS="$_fc_saved_ifs"

        # Dispatch to radio widget
        eval "$_fc_eval"
        _fc_rc=$?

        # Check cancellation (Esc in radio returns 1)
        if [ "$_fc_rc" -ne 0 ]; then
          rm -f "$_fc_tmp"
          unset _fc_param_string _fc_parsed _fc_parse_rc _fc_tmp
          unset _fc_idx _fc_name _fc_type _fc_choices
          unset _fc_count _fc_saved_ifs _fc_ch _fc_safe _fc_eval _fc_rc
          return 1
        fi

        # Map 0-based index from TUI_RESULT to the corresponding choice string
        _fc_target=$((TUI_RESULT + 1))
        _fc_i=1
        _fc_sel_text=''
        IFS=','
        for _fc_ch in $_fc_choices; do
          if [ "$_fc_i" -eq "$_fc_target" ]; then
            _fc_sel_text="$_fc_ch"
            break
          fi
          _fc_i=$((_fc_i + 1))
        done
        IFS="$_fc_saved_ifs"

        # Append --key value to args
        _flu_module_args="${_flu_module_args} --${_fc_name} ${_fc_sel_text}"
        ;;

      text)
        # Dispatch to text input widget
        tui_text_input "$_fc_name" "Enter $_fc_name"
        _fc_rc=$?

        # Check cancellation (Esc in text returns 1)
        if [ "$_fc_rc" -ne 0 ]; then
          rm -f "$_fc_tmp"
          unset _fc_param_string _fc_parsed _fc_parse_rc _fc_tmp
          unset _fc_idx _fc_name _fc_type _fc_choices
          unset _fc_count _fc_saved_ifs _fc_ch _fc_safe _fc_eval _fc_rc
          unset _fc_target _fc_i _fc_sel_text
          return 1
        fi

        # Append --key value to args (TUI_RESULT holds typed string)
        _flu_module_args="${_flu_module_args} --${_fc_name} ${TUI_RESULT}"
        ;;

      yesno)
        # Dispatch to yes/no confirmation widget (defaults to "no")
        tui_yesno "$_fc_name" "Enable $_fc_name?" "no"
        _fc_rc=$?

        # Check cancellation (Esc in yesno returns 1)
        if [ "$_fc_rc" -ne 0 ]; then
          rm -f "$_fc_tmp"
          unset _fc_param_string _fc_parsed _fc_parse_rc _fc_tmp
          unset _fc_idx _fc_name _fc_type _fc_choices
          unset _fc_count _fc_saved_ifs _fc_ch _fc_safe _fc_eval _fc_rc
          unset _fc_target _fc_i _fc_sel_text
          return 1
        fi

        # Append --key value to args (TUI_RESULT holds 'yes' or 'no')
        _flu_module_args="${_flu_module_args} --${_fc_name} ${TUI_RESULT}"
        ;;

      *)
        # Unknown type — treat as text input (safe default)
        tui_text_input "$_fc_name" "Enter $_fc_name"
        _fc_rc=$?
        if [ "$_fc_rc" -ne 0 ]; then
          rm -f "$_fc_tmp"
          unset _fc_param_string _fc_parsed _fc_parse_rc _fc_tmp
          unset _fc_idx _fc_name _fc_type _fc_choices
          unset _fc_count _fc_saved_ifs _fc_ch _fc_safe _fc_eval _fc_rc
          unset _fc_target _fc_i _fc_sel_text
          return 1
        fi
        _flu_module_args="${_flu_module_args} --${_fc_name} ${TUI_RESULT}"
        ;;
    esac
  done < "$_fc_tmp"

  # Cleanup
  rm -f "$_fc_tmp"
  unset _fc_param_string _fc_parsed _fc_parse_rc _fc_tmp
  unset _fc_idx _fc_name _fc_type _fc_choices
  unset _fc_count _fc_saved_ifs _fc_ch _fc_safe _fc_eval _fc_rc
  unset _fc_target _fc_i _fc_sel_text
  return 0
}

# ---------------------------------------------------------------------------
# Section 8: _flu_execute_with_timeout() — Timeout-enforced module execution
# ---------------------------------------------------------------------------

# _flu_execute_with_timeout <timeout_sec> <script_path> [args...]
# Executes a module script with timeout enforcement (D-15).
# Tries the `timeout` command first. Falls back to background+kill
# watchdog pattern on systems without `timeout` (embedded, busybox).
#
# Sets global _flu_exit_code to the module's exit code.
# Returns 0 on success, non-zero on failure or timeout (124).
# Module runs with set -eu strict mode + EXIT trap (D-14).
_flu_execute_with_timeout() {
  _fet_timeout="$1"; shift
  _fet_script="$1"; shift
  # Remaining args ("$@") are module arguments (--key value pairs)

  if command -v timeout >/dev/null 2>&1; then
    # Preferred path: use timeout command
    timeout "$_fet_timeout" sh -c '
      trap '\''_fe_trap_rc=$?'\'' EXIT
      # Module execution with strict error handling (set -euo pipefail equivalent)
      set -eu
      _fet_script="$1"; shift
      sh "$_fet_script" -- "$@"
    ' _fet_wrapper "$_fet_script" "$@"
    _fet_rc=$?
  else
    # Fallback: background process + watchdog kill pattern
    # POSIX-compatible — no `timeout` command needed
    (
      trap '_fe_trap_rc=$?' EXIT
      # Module execution with strict error handling (set -euo pipefail equivalent)
      set -eu
      sh "$_fet_script" -- "$@"
    ) &
    _fet_pid=$!
    (
      sleep "$_fet_timeout"
      kill "$_fet_pid" 2>/dev/null || true
    ) &
    _fet_watchdog=$!
    wait "$_fet_pid" 2>/dev/null
    _fet_rc=$?
    # Kill the watchdog if still running
    kill "$_fet_watchdog" 2>/dev/null || true
    wait "$_fet_watchdog" 2>/dev/null || true

    # If killed by signal (rc > 128), treat as timeout (D-15)
    if [ "$_fet_rc" -gt 128 ] 2>/dev/null; then
      _fet_rc=124
    fi
  fi

  _flu_exit_code=$_fet_rc
  unset _fet_timeout _fet_script _fet_pid _fet_watchdog _fet_rc
  return $_flu_exit_code
}

# ---------------------------------------------------------------------------
# Section 9: flu_module_execute() — Module execution orchestrator
# ---------------------------------------------------------------------------

# flu_module_execute <action_id>
# Full module execution pipeline following the D-09 execution order:
#   1. Fetch module script from GitHub
#   2. Parse metadata from comment header
#   3. Set platform context environment variables
#   4. Check platform compatibility
#   5. Collect parameter values from user via TUI widgets
#   6. Execute module in isolated subshell with timeout
#   7. Display execution status
#
# Returns 0 on successful execution, 1 on any failure (fetch, parse,
# platform mismatch, user cancellation, or module error).
flu_module_execute() {
  _fme_action="$1"

  # Guard: verify tui.sh has been sourced
  if [ -z "${TUI_RESET:-}" ]; then
    printf '%s[ERROR]%s tui.sh must be sourced before calling flu_module_execute\n' \
      "$TUI_RED" "$TUI_RESET" >&2
    return 1
  fi

  # Step 1: Fetch module script to temp file
  _fetmp="/tmp/flu_module_$$.sh"
  flu_module_fetch "$_fme_action" > "$_fetmp" || {
    rm -f "$_fetmp"
    unset _fme_action _fetmp
    return 1
  }

  # Step 2: Parse metadata from fetched script
  flu_module_parse_metadata < "$_fetmp" || {
    rm -f "$_fetmp"
    unset _fme_action _fetmp
    return 1
  }

  # Step 3: Set platform context env vars (exports all 7 FLU_* vars)
  flu_module_set_env

  # Step 4: Platform compatibility check (defense in depth)
  _fme_os_match=false
  _fme_saved_ifs="$IFS"
  IFS=','
  for _fme_p in $_fmp_platforms; do
    _fme_p=$(printf '%s' "$_fme_p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ "$_fme_p" = "$FLU_OS" ]; then
      _fme_os_match=true
      break
    fi
  done
  IFS="$_fme_saved_ifs"

  if [ "$_fme_os_match" != "true" ]; then
    printf '%s[ERROR]%s Module "%s" not available for this platform (%s)\n' \
      "$TUI_RED" "$TUI_RESET" "${_fmp_name:-?}" "$FLU_OS" >&2
    rm -f "$_fetmp"
    unset _fme_action _fetmp _fme_os_match _fme_saved_ifs _fme_p
    return 1
  fi

  # Step 5: Collect parameter values from user
  if [ -n "${_fmp_params:-}" ]; then
    flu_module_collect_params "$_fmp_params" || {
      # User cancelled at a prompt — abort gracefully
      printf '%s[CANCELLED]%s Parameter collection cancelled\n' \
        "$TUI_YELLOW" "$TUI_RESET" >&2
      rm -f "$_fetmp"
      unset _fme_action _fetmp _fme_os_match _fme_saved_ifs _fme_p
      return 1
    }
  fi

  # Step 6: Execute module with timeout enforcement
  _fme_timeout="${_fmp_timeout:-300}"
  # shellcheck disable=SC2086  # _flu_module_args must split into multiple --key value pairs
  _flu_execute_with_timeout "$_fme_timeout" "$_fetmp" $_flu_module_args
  _fme_exit_code=$?

  # Step 7: Display execution status
  _flu_module_show_status "$_fme_exit_code" "${_fmp_name:-Module}"

  # Cleanup temp file
  rm -f "$_fetmp"
  unset _fme_action _fetmp _fme_os_match _fme_saved_ifs _fme_p
  unset _fme_timeout _fme_exit_code
  return "$_fme_exit_code"
}

# ---------------------------------------------------------------------------
# Section 10: _flu_module_show_status() — Execution result display
# ---------------------------------------------------------------------------

# _flu_module_show_status <exit_code> <module_name>
# Prints a color-coded status line indicating success or failure.
# Green ✓ for exit code 0, red ✗ with exit code for non-zero.
# This stub function will be replaced by the full result modal in Plan 04-03.
_flu_module_show_status() {
  _fmss_rc="$1"
  _fmss_name="$2"

  printf '\n'
  if [ "$_fmss_rc" -eq 0 ]; then
    printf '%s  ✓  %s completed successfully%s\n' \
      "$TUI_GREEN" "$_fmss_name" "$TUI_RESET"
  else
    printf '%s  ✗  %s failed (exit code: %d)%s\n' \
      "$TUI_RED" "$_fmss_name" "$_fmss_rc" "$TUI_RESET"
  fi
  printf '\n'

  unset _fmss_rc _fmss_name
}
