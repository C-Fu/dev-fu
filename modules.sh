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
  _fmr_base="${FLU_MODULES_BASE_URL:-https://raw.githubusercontent.com/C-Fu/dev-fu/flu.sh/modules/}"
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

  # Check for local module first — co-located with flu.sh in modules/
  if [ -n "${FLU_SCRIPT_DIR:-}" ] && [ -f "${FLU_SCRIPT_DIR}/modules/${_fmf_action}.sh" ]; then
    cat "${FLU_SCRIPT_DIR}/modules/${_fmf_action}.sh"
    unset _fmf_action
    return 0
  fi

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
  return "$_fpp_rc"
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

  # Use background+watchdog pattern primarily — timeout(1) creates
  # a new process group which causes SIGTTIN when the child (sudo)
  # tries to read from /dev/tty. Background processes don't have
  # this limitation.
  (
    trap 'exit 130' INT TERM
    trap '_fe_trap_rc=$?' EXIT
    set -eu
    sh "$_fet_script" -- "$@"
  ) &
  _fet_pid=$!
  (
    sleep "$_fet_timeout"
    kill -9 "$_fet_pid" 2>/dev/null || true
  ) &
  _fet_watchdog=$!
  wait "$_fet_pid" 2>/dev/null
  _fet_rc=$?
  kill -9 "$_fet_watchdog" 2>/dev/null || true
  wait "$_fet_watchdog" 2>/dev/null || true

  if [ "$_fet_rc" -gt 128 ] 2>/dev/null; then
    _fet_rc=124
  fi

  _flu_exit_code=${_fet_rc:-1}
  unset _fet_timeout _fet_script _fet_pid _fet_watchdog _fet_rc
  return "$_flu_exit_code"
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

  # Step 6: Execute module with timeout enforcement, capture outputs
  # Reset terminal to sane cooked mode so sudo/ssh work properly
  stty sane 2>/dev/null < /dev/tty || true
  _fme_timeout="${_fmp_timeout:-300}"
  _fme_out="/tmp/flu_module_out_$$"
  _fme_err="/tmp/flu_module_err_$$"
  # shellcheck disable=SC2086  # _flu_module_args must split into multiple --key value pairs
  _flu_execute_with_timeout "$_fme_timeout" "$_fetmp" $_flu_module_args >"$_fme_out" 2>"$_fme_err"
  _fme_exit_code=$?

  # Read captured output from temp files
  _flu_module_output=$(cat "$_fme_out" 2>/dev/null)
  _flu_module_stderr=$(cat "$_fme_err" 2>/dev/null)
  rm -f "$_fme_out" "$_fme_err"

  # Display results in box-rendered modal
  # On success: show module stdout. On failure: show stderr + recovery hints.
  if [ "$_fme_exit_code" -eq 0 ]; then
    flu_module_display_result 0 "$_flu_module_output" "${_fmp_name:-Module}"
  else
    flu_module_display_result "$_fme_exit_code" "$_flu_module_stderr" "${_fmp_name:-Module}"
  fi

  # Cleanup temp files
  rm -f "$_fetmp" "$_fme_out" "$_fme_err" 2>/dev/null
  
  # Save exit code before unsetting the variable
  _fme_ret=${_fme_exit_code:-1}
  unset _fme_action _fetmp _fme_os_match _fme_saved_ifs _fme_p
  unset _fme_timeout _fme_exit_code _fme_out _fme_err
  unset _flu_module_output _flu_module_stderr
  return "$_fme_ret"
}

# ---------------------------------------------------------------------------
# Section 10: flu_module_display_result() — Box-rendered result modal
# ---------------------------------------------------------------------------

# _flu_wait_for_key
# Reads a single keypress from /dev/tty and discards it.
# Used to pause before returning to menu after viewing results.
# Uses _tui_read_key from tui.sh which sets _tui_rk_result.
_flu_wait_for_key() {
  _tui_read_key
}

# flu_module_display_result <exit_code> <output> <name>
# Displays module execution results in a box-rendered modal (D-12, D-13).
# Success (exit 0): green ✓ status banner with module stdout content.
# Failure (exit != 0): red ✗ status banner with exit code, stderr
#   content and actionable recovery hints.
# User presses any key to dismiss the modal and return to menu.
#
# Replaces the _flu_module_show_status stub from Plan 04-02 with
# the full D-12/D-13 box-rendered result modal implementation.
flu_module_display_result() {
  _fdr_exit_code=$1
  _fdr_output=$2
  _fdr_name=$3

  # Guard: verify tui.sh has been sourced
  if [ -z "${TUI_RESET:-}" ]; then
    printf 'Error: tui.sh must be sourced before calling flu_module_display_result\n' >&2
    return 1
  fi

  # Init TUI (terminal raw mode, signal traps)
  tui_init

  # Clear screen
  clear_screen

  # Get terminal size with fallbacks
  _fdr_rows=$(tput lines 2>/dev/null || printf '24')
  _fdr_cols=$(tput cols 2>/dev/null || printf '80')

  # Calculate box dimensions — use full terminal width
  _fdr_box_w=$((_fdr_cols - 4))
  [ "$_fdr_box_w" -lt 40 ] && _fdr_box_w=40
  _fdr_box_h=$((_fdr_rows - 4))
  _fdr_x=$(( (_fdr_cols - _fdr_box_w) / 2 ))
  [ "$_fdr_x" -lt 1 ] && _fdr_x=1
  _fdr_y=2

  # Build status banner title (D-12)
  if [ "$_fdr_exit_code" -eq 0 ]; then
    _fdr_title="✓ ${_fdr_name} — Complete"
    _fdr_title_color="${TUI_GREEN}"
  else
    _fdr_title="✗ ${_fdr_name} — Failed (exit: ${_fdr_exit_code})"
    _fdr_title_color="${TUI_RED}"
  fi

  # Draw the box with status-colored title
  _tui_draw_box "$_fdr_x" "$_fdr_y" "$_fdr_box_w" "$_fdr_box_h" \
    "${_fdr_title_color}${_fdr_title}${TUI_RESET}"

  # Inner width for content (2 for borders + 2 padding)
  _fdr_inner=$((_fdr_box_w - 4))

  # Write output to temp file for line-by-line reading.
  # Avoids POSIX pipe subshell issue where while-read in a pipeline
  # creates a subshell that loses variable state.
  _fdr_tmp="/tmp/flu_result_$$"
  printf '%s\n' "$_fdr_output" > "$_fdr_tmp"

  # Render output content inside the box (D-13)
  # Start at row y+3 (after title row, separator, and one padding row)
  _fdr_content_row=$((_fdr_y + 3))
  _fdr_max_row=$((_fdr_y + _fdr_box_h - 4))
  _fdr_line_count=0

  while IFS= read -r _fdr_line; do
    [ "$_fdr_content_row" -ge "$_fdr_max_row" ] && break

    # Truncate line to fit inner width
    _fdr_truncated=$(printf '%s' "$_fdr_line" | awk -v L="$_fdr_inner" \
      '{print substr($0,1,L)}')

    move_cursor "$_fdr_content_row" $((_fdr_x + 2))
    printf '%s' "$_fdr_truncated"

    _fdr_content_row=$((_fdr_content_row + 1))
    _fdr_line_count=$((_fdr_line_count + 1))
  done < "$_fdr_tmp"

  rm -f "$_fdr_tmp"

  # If no output but non-zero exit, show explanation
  if [ "$_fdr_exit_code" -ne 0 ] && [ "$_fdr_line_count" -eq 0 ]; then
    move_cursor "$_fdr_content_row" $((_fdr_x + 2))
    printf '%sModule exited with code %d but produced no error output.%s' \
      "$TUI_YELLOW" "$_fdr_exit_code" "$TUI_RESET"
  fi

  # Failure: display recovery hints (D-13)
  if [ "$_fdr_exit_code" -ne 0 ]; then
    _flu_display_recovery_hints "$_fdr_exit_code"
  fi

  # Footer: "Press any key to return to menu"
  _fdr_footer_row=$((_fdr_y + _fdr_box_h - 2))
  move_cursor "$_fdr_footer_row" $((_fdr_x + 2))
  printf '%sPress any key to return to menu%s' "$TUI_DIM" "$TUI_RESET"

  # Wait for keypress
  _flu_wait_for_key

  # Restore terminal (restores stty, clears screen, removes traps)
  tui_restore

  # Cleanup
  unset _fdr_exit_code _fdr_output _fdr_name
  unset _fdr_rows _fdr_cols _fdr_box_w _fdr_box_h _fdr_x _fdr_y
  unset _fdr_title _fdr_title_color _fdr_inner _fdr_tmp
  unset _fdr_content_row _fdr_max_row _fdr_line_count _fdr_line _fdr_truncated
  unset _fdr_footer_row
}

# ---------------------------------------------------------------------------
# Section 11: _flu_display_recovery_hints() — Error recovery hints
# ---------------------------------------------------------------------------

# _flu_display_recovery_hints <exit_code>
# Displays actionable recovery hints inside the result box (D-13).
# Called from flu_module_display_result on failure path.
# Maps common exit codes and error patterns to human-readable hints
# rendered in TUI_YELLOW at the bottom of the result modal.
#
# Accesses _fdr_* variables from flu_module_display_result context:
#   _fdr_y, _fdr_box_h, _fdr_x, _fdr_inner, _fdr_output
_flu_display_recovery_hints() {
  _fdh_exit_code=$1

  # Guard: verify tui.sh has been sourced (defense in depth)
  if [ -z "${TUI_RESET:-}" ]; then
    return 1
  fi

  # Determine hint based on exit code and error patterns
  _fdh_hint=''

  case "$_fdh_exit_code" in
    124)
      _fdh_hint="The operation timed out after ${_fmp_timeout:-300} seconds. Try again with a faster connection or check if the service is responsive."
      ;;
    126)
      _fdh_hint="The module script could not be executed. This may indicate a corrupted download. Try running again."
      ;;
    127)
      _fdh_hint="A required command was not found. Check that all dependencies are installed for this module."
      ;;
    1)
      # Check output content for specific error patterns
      case "$_fdr_output" in
        *curl*|*wget*|*fetch*)
          _fdh_hint="Network error — unable to reach the server. Check your internet connection. If you are behind a proxy, set HTTP_PROXY and HTTPS_PROXY environment variables."
          ;;
        *"Permission denied"*|*"permission denied"*)
          _fdh_hint="Permission denied — try with elevated privileges."
          ;;
        *"not found"*|*"Not found"*)
          _fdh_hint="A required dependency was not found. Check that all dependencies are installed for this module."
          ;;
        *)
          _fdh_hint="Module exited with code 1. Check the output above for details. You can re-run this operation to try again."
          ;;
      esac
      ;;
    6|7|22|28)
      _fdh_hint="Network error — unable to reach the server. Check your internet connection. If you are behind a proxy, set HTTP_PROXY and HTTPS_PROXY environment variables."
      ;;
    *)
      _fdh_hint="Module exited with code ${_fdh_exit_code}. Check the output above for details. You can re-run this operation to try again."
      ;;
  esac

  # Render hint inside the result box.
  # Position two rows above bottom border, above "Press any key" footer.
  _fdh_row=$((_fdr_y + _fdr_box_h - 4))

  # Calculate hint display width (inner width minus arrow prefix padding)
  _fdh_hint_width=$((_fdr_inner - 4))

  # Word-wrap the hint text to fit box inner width, write to temp file
  _fdh_tmp="/tmp/flu_hint_$$"
  printf '%s' "$_fdh_hint" | awk -v W="$_fdh_hint_width" '
    {
      line = $0
      while (length(line) > W) {
        pos = W
        while (pos > 0 && substr(line, pos, 1) != " ") pos--
        if (pos == 0) { pos = W }
        print substr(line, 1, pos)
        line = substr(line, pos+1)
        sub(/^[[:space:]]+/, "", line)
      }
      if (length(line) > 0) print line
    }
  ' > "$_fdh_tmp"

  # Render each wrapped line with yellow arrow prefix
  while IFS= read -r _fdh_line; do
    [ "$_fdh_row" -ge $((_fdr_y + _fdr_box_h - 2)) ] && break
    move_cursor "$_fdh_row" $((_fdr_x + 2))
    printf '%s→ %s%s' "$TUI_YELLOW" "$_fdh_line" "$TUI_RESET"
    _fdh_row=$((_fdh_row + 1))
  done < "$_fdh_tmp"

  rm -f "$_fdh_tmp"

  unset _fdh_exit_code _fdh_hint _fdh_row _fdh_line _fdh_tmp _fdh_hint_width
}
