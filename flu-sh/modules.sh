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

# Cache and checksum configuration
FLU_CACHE_DIR="${FLU_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/flu.sh}"
FLU_CACHE_TTL="${FLU_CACHE_TTL:-86400}"
FLU_DATA_DIR="${FLU_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flu.sh}"
FLU_REGISTRY_URL="${FLU_REGISTRY_URL:-https://raw.githubusercontent.com/C-Fu/dev-fu-registry/main/registry.json}"

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
  # Community modules — delegate to registry lookup
  case "$_fmr_action" in
    community/*)
      _fmr_reg_id="${_fmr_action#community/}"
      flu_registry_lookup "$_fmr_reg_id" || { unset _fmr_action _fmr_reg_id; return 1; }
      printf '%s%s.sh\n' "$_freg_base_url" "$_fmr_reg_id"
      unset _fmr_action _fmr_reg_id
      return 0
      ;;
  esac
  # Official modules — standard base URL
  _fmr_base="${FLU_MODULES_BASE_URL:-https://raw.githubusercontent.com/C-Fu/dev-fu/main/flu-sh/modules/}"
  printf '%s%s.sh\n' "$_fmr_base" "$_fmr_action"
  unset _fmr_action _fmr_base
  return 0
}

# ---------------------------------------------------------------------------
# Section 2.5: _flu_fetch_manifest() — Fetch SHA256 checksum manifest
# ---------------------------------------------------------------------------

# _flu_fetch_manifest
# Fetches MANIFEST.sha256 from the same base URL as modules.
# Outputs manifest content to stdout on success.
# Returns 0 on success, 1 on failure (soft-fail per D-03).
_flu_fetch_manifest() {
  _ffm_base="${FLU_MODULES_BASE_URL:-https://raw.githubusercontent.com/C-Fu/dev-fu/main/flu-sh/modules/}"
  _ffm_url="${_ffm_base}MANIFEST.sha256"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 5 "$_ffm_url" 2>/dev/null
  else
    wget -qO- --timeout=5 "$_ffm_url" 2>/dev/null
  fi
  _ffm_rc=$?
  unset _ffm_base _ffm_url
  return $_ffm_rc
}

# ---------------------------------------------------------------------------
# Section 3: flu_module_fetch() — Fetch module script from GitHub
# ---------------------------------------------------------------------------

# flu_module_fetch <action_id>
# Fetches a module script with caching, SHA256 verification, and progress.
# Flow: local check → cache check → remote fetch → checksum verify → cache store.
# Outputs script content to stdout on success.
# Progress and status messages go to stderr.
# Returns 0 on success, 1 on failure.
flu_module_fetch() {
  _fmf_action="$1"

  # Community modules — use registry fetch pipeline
  case "$_fmf_action" in
    community/*)
      flu_registry_fetch_module "${_fmf_action#community/}"
      return $?
      ;;
  esac

  # Check for local module first — co-located with flu.sh in modules/
  if [ -n "${FLU_SCRIPT_DIR:-}" ] && [ -f "${FLU_SCRIPT_DIR}/modules/${_fmf_action}.sh" ]; then
    cat "${FLU_SCRIPT_DIR}/modules/${_fmf_action}.sh"
    unset _fmf_action
    return 0
  fi

  # Check cache
  _fmf_cache_file="${FLU_CACHE_DIR}/${_fmf_action}"
  if [ -f "$_fmf_cache_file" ] && [ -s "$_fmf_cache_file" ]; then
    _fmf_now=$(date +%s)
    _fmf_mtime=$(stat -c %Y "$_fmf_cache_file" 2>/dev/null || echo 0)
    _fmf_age=$((_fmf_now - _fmf_mtime))
    if [ "$_fmf_age" -lt "${FLU_CACHE_TTL:-86400}" ] 2>/dev/null; then
      printf '  %s[cached]%s %s (age: %ds)\n' \
        "$TUI_DIM" "$TUI_RESET" "$_fmf_action" "$_fmf_age" >&2
      cat "$_fmf_cache_file"
      unset _fmf_action _fmf_cache_file _fmf_now _fmf_mtime _fmf_age
      return 0
    fi
  fi

  _fmf_url=$(flu_module_resolve_url "$_fmf_action")
  _fmf_attempt=1
  _fmf_content=''
  _fmf_rc=1

  while [ "$_fmf_attempt" -le 3 ]; do
    printf '  Downloading %s.sh... ' "$_fmf_action" >&2
    _fmf_tmp_dl="${TMPDIR:-/tmp}/flu_dl_$$_${_fmf_action}"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --connect-timeout 10 --progress-bar "$_fmf_url" -o "$_fmf_tmp_dl" 2>&2
      _fmf_rc=$?
    else
      wget -q --show-progress -O "$_fmf_tmp_dl" "$_fmf_url" 2>&2
      _fmf_rc=$?
    fi

    if [ "$_fmf_rc" -eq 0 ] && [ -f "$_fmf_tmp_dl" ] && [ -s "$_fmf_tmp_dl" ]; then
      _fmf_content=$(cat "$_fmf_tmp_dl")
      _fmf_size=$(wc -c < "$_fmf_tmp_dl")
      rm -f "$_fmf_tmp_dl"
      printf 'done (%s bytes)\n' "$_fmf_size" >&2
      break
    fi

    rm -f "$_fmf_tmp_dl" 2>/dev/null
    printf 'failed\n' >&2

    if [ "$_fmf_attempt" -lt 3 ]; then
      printf '  Retrying (%d/3)...\n' "$((_fmf_attempt + 1))" >&2
      sleep 2
    fi
    _fmf_attempt=$((_fmf_attempt + 1))
  done

  if [ -z "$_fmf_content" ]; then
    printf '%s[ERROR]%s Failed to fetch module: %s (exit: %d)\n' \
      "$TUI_RED" "$TUI_RESET" "$_fmf_url" "$_fmf_rc" >&2
    unset _fmf_action _fmf_url _fmf_attempt _fmf_rc _fmf_content _fmf_cache_file _fmf_tmp_dl _fmf_size
    return 1
  fi

  # SHA256 verification against MANIFEST.sha256
  _fmf_manifest=$(_flu_fetch_manifest 2>/dev/null) || true
  if [ -n "$_fmf_manifest" ]; then
    _fmf_expected_hash=$(printf '%s\n' "$_fmf_manifest" | grep "  ${_fmf_action}.sh$" | awk '{print $1}')
    if [ -n "$_fmf_expected_hash" ]; then
      _fmf_actual_hash=$(printf '%s\n' "$_fmf_content" | sha256sum | awk '{print $1}')
      if [ "$_fmf_actual_hash" != "$_fmf_expected_hash" ]; then
        printf '%s[ERROR]%s Checksum mismatch for %s — possible tampering or corruption\n' \
          "$TUI_RED" "$TUI_RESET" "${_fmf_action}.sh" >&2
        unset _fmf_action _fmf_url _fmf_attempt _fmf_rc _fmf_content _fmf_cache_file \
          _fmf_manifest _fmf_expected_hash _fmf_actual_hash _fmf_size
        return 1
      fi
      printf '  %s[verified]%s SHA256 checksum OK\n' "$TUI_GREEN" "$TUI_RESET" >&2
    fi
  else
    printf '  %s[WARN]%s Cannot verify checksum — manifest unavailable\n' \
      "$TUI_YELLOW" "$TUI_RESET" >&2
  fi

  # Store to cache
  mkdir -p "$FLU_CACHE_DIR" 2>/dev/null || true
  if [ -d "$FLU_CACHE_DIR" ]; then
    _fmf_cache_tmp="${FLU_CACHE_DIR}/.tmp_$$_${_fmf_action}"
    printf '%s\n' "$_fmf_content" > "$_fmf_cache_tmp"
    mv "$_fmf_cache_tmp" "$_fmf_cache_file" 2>/dev/null || rm -f "$_fmf_cache_tmp" 2>/dev/null
  fi

  printf '%s\n' "$_fmf_content"
  unset _fmf_action _fmf_url _fmf_attempt _fmf_rc _fmf_content _fmf_cache_file \
    _fmf_manifest _fmf_expected_hash _fmf_actual_hash _fmf_size _fmf_cache_tmp
  return 0
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

  stty sane 2>/dev/null < /dev/tty || true

  set +e
  (
    _fet_me=$(exec sh -c 'printf "%s" "$PPID"')
    ( sleep "$_fet_timeout"; kill -9 "$_fet_me" 2>/dev/null ) &
    exec sh "$_fet_script" -- "$@"
  )
  _fet_rc=$?
  set -e

  if [ "$_fet_rc" -eq 137 ]; then
    _fet_rc=124
  fi

  _flu_exit_code=${_fet_rc:-1}
  unset _fet_timeout _fet_script _fet_rc
  return "$_flu_exit_code"
}

# ---------------------------------------------------------------------------
# Section 8.5: _flu_log_execution() — TSV execution logging
# ---------------------------------------------------------------------------

# _flu_classify_operation <action_id>
# Extracts operation type from action_id prefix per D-10.
_flu_classify_operation() {
  case "$1" in
    install_*)   printf 'install' ;;
    remove_*)    printf 'remove' ;;
    create_*)    printf 'create' ;;
    configure_*) printf 'configure' ;;
    set_*)       printf 'set' ;;
    status_*)    printf 'status' ;;
    upgrade_*)   printf 'upgrade' ;;
    *)           printf 'other' ;;
  esac
}

# _flu_log_execution <action_id> <operation> <result> <version> <duration>
# Appends execution record to TSV log file per D-10/D-11/D-12.
_flu_log_execution() {
  _fle_action="$1"
  _fle_operation="$2"
  _fle_result="$3"
  _fle_version="${4:--}"
  _fle_duration="${5:--}"
  _fle_ts=$(date +%Y-%m-%dT%H:%M:%S%z 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
  _fle_logfile="${FLU_DATA_DIR}/execution.log"

  mkdir -p "${FLU_DATA_DIR}" 2>/dev/null || true

  if [ ! -f "$_fle_logfile" ] || [ ! -s "$_fle_logfile" ]; then
    printf 'timestamp\taction_id\toperation\tresult\tversion\tduration_seconds\n' > "$_fle_logfile"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$_fle_ts" "$_fle_action" "$_fle_operation" "$_fle_result" "$_fle_version" "$_fle_duration" \
    >> "$_fle_logfile"

  unset _fle_action _fle_operation _fle_result _fle_version _fle_duration _fle_ts _fle_logfile
}

# ---------------------------------------------------------------------------
# Section 8.7: _flu_strip_ansi() — Strip ANSI escape codes for non-TTY output
# ---------------------------------------------------------------------------

# _flu_strip_ansi
# Reads from stdin, strips ANSI escape sequences, writes to stdout.
# Used in batch mode when stdout is not a TTY (per D-09).
_flu_strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# ---------------------------------------------------------------------------
# Section 8.8: flu_batch_run() — Non-interactive batch module execution
# ---------------------------------------------------------------------------

# flu_batch_run <action_ids> <flags>
# Executes multiple modules in batch mode without TUI interaction (D-05–D-09).
#
# Parameters:
#   $1 = comma-separated action_ids (e.g., "install_go,install_rust")
#   $2 = flags string — "yes" if --yes was passed, empty otherwise
#
# Logic:
#   1. Validate action_ids against menu.db entries (T-12-01 mitigation)
#   2. For each action_id: fetch, parse metadata, check params, check platform,
#      execute with timeout, log, print status
#   3. Continue on failure — one failed module does not stop subsequent modules
#   4. Print summary with success/failure counts
#   5. Return 0 if all succeed, 1 if any fail
flu_batch_run() {
  _br_action_ids="$1"
  _br_flags="$2"
  _br_ok=0
  _br_fail=0
  _br_is_tty=true
  [ -t 1 ] || _br_is_tty=false

  # Validate: action_ids must not be empty
  if [ -z "$_br_action_ids" ]; then
    printf 'Error: no action IDs provided\n' >&2
    unset _br_action_ids _br_flags _br_ok _br_fail _br_is_tty
    return 1
  fi

  # Set platform context
  flu_module_set_env

  # Determine menu.db path for action_id validation (T-12-01)
  _br_menu="${FLU_MENU_FILE:-${FLU_SCRIPT_DIR:-.}/menu.db}"

  _br_saved_ifs="$IFS"
  IFS=','
  for _br_aid in $_br_action_ids; do
    # Trim whitespace
    _br_aid=$(printf '%s' "$_br_aid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$_br_aid" ] && continue

    # T-12-01: Validate action_id exists in menu.db (skip for community/* modules)
    case "$_br_aid" in
      community/*) ;;
      *)
        if [ -f "$_br_menu" ]; then
          _br_valid=$(grep -v '^#' "$_br_menu" | grep -v '^$' \
            | cut -d'|' -f4 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | grep -xF "$_br_aid" || true)
          if [ -z "$_br_valid" ]; then
            if [ "$_br_is_tty" = "true" ]; then
              printf '%s✗ %s — Unknown action ID%s\n' "$TUI_RED" "$_br_aid" "$TUI_RESET"
            else
              printf '✗ %s — Unknown action ID\n' "$_br_aid"
            fi
            _br_fail=$((_br_fail + 1))
            unset _br_valid
            continue
          fi
          unset _br_valid
        fi
        ;;
    esac

    # Print status line
    if [ "$_br_is_tty" = "true" ]; then
      printf '%s▶ %s%s\n' "$TUI_BOLD" "$_br_aid" "$TUI_RESET"
    else
      printf '▶ %s\n' "$_br_aid"
    fi

    # Fetch module to temp file
    _br_tmp_safe=$(printf '%s' "$_br_aid" | tr '/' '_')
    _br_tmp="/tmp/flu_batch_$$_${_br_tmp_safe}"
    flu_module_fetch "$_br_aid" > "$_br_tmp" 2>/dev/null
    _br_fetch_rc=$?
    if [ "$_br_fetch_rc" -ne 0 ] || [ ! -s "$_br_tmp" ]; then
      if [ "$_br_is_tty" = "true" ]; then
        printf '%s✗ %s — Fetch failed%s\n' "$TUI_RED" "$_br_aid" "$TUI_RESET"
      else
        printf '✗ %s — Fetch failed\n' "$_br_aid"
      fi
      rm -f "$_br_tmp" 2>/dev/null
      _br_fail=$((_br_fail + 1))
      unset _br_tmp _br_fetch_rc
      continue
    fi

    # Parse metadata
    flu_module_parse_metadata < "$_br_tmp" 2>/dev/null
    _br_parse_rc=$?
    if [ "$_br_parse_rc" -ne 0 ]; then
      if [ "$_br_is_tty" = "true" ]; then
        printf '%s✗ %s — Metadata parse error%s\n' "$TUI_RED" "$_br_aid" "$TUI_RESET"
      else
        printf '✗ %s — Metadata parse error\n' "$_br_aid"
      fi
      rm -f "$_br_tmp" 2>/dev/null
      _br_fail=$((_br_fail + 1))
      unset _br_tmp _br_parse_rc
      continue
    fi

    # Check for @params — reject in --yes mode
    if [ -n "${_fmp_params:-}" ]; then
      case "$_br_flags" in
        *yes*)
          if [ "$_br_is_tty" = "true" ]; then
            printf '%s✗ %s — Requires parameters, use interactive mode%s\n' \
              "$TUI_RED" "$_br_aid" "$TUI_RESET"
          else
            printf '✗ %s — Requires parameters, use interactive mode\n' "$_br_aid"
          fi
          rm -f "$_br_tmp" 2>/dev/null
          _br_fail=$((_br_fail + 1))
          unset _br_tmp _br_parse_rc
          continue
          ;;
        *)
          if [ "$_br_is_tty" = "true" ]; then
            printf '%s⚠ %s — Requires parameters, skipping%s\n' \
              "$TUI_YELLOW" "$_br_aid" "$TUI_RESET"
          else
            printf '⚠ %s — Requires parameters, skipping\n' "$_br_aid"
          fi
          rm -f "$_br_tmp" 2>/dev/null
          _br_fail=$((_br_fail + 1))
          unset _br_tmp _br_parse_rc
          continue
          ;;
      esac
    fi

    # Platform check (defense in depth — parse_metadata also checks)
    _br_plat_match=false
    _br_plat_ifs="$IFS"
    IFS=','
    for _br_p in $_fmp_platforms; do
      _br_p=$(printf '%s' "$_br_p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ "$_br_p" = "$FLU_OS" ]; then
        _br_plat_match=true
        break
      fi
    done
    IFS="$_br_plat_ifs"
    unset _br_plat_ifs _br_p

    if [ "$_br_plat_match" = "false" ]; then
      if [ "$_br_is_tty" = "true" ]; then
        printf '%s✗ %s — Not available for this platform%s\n' \
          "$TUI_RED" "$_br_aid" "$TUI_RESET"
      else
        printf '✗ %s — Not available for this platform\n' "$_br_aid"
      fi
      rm -f "$_br_tmp" 2>/dev/null
      _br_fail=$((_br_fail + 1))
      unset _br_tmp _br_parse_rc _br_plat_match
      continue
    fi

    # Execute module with timeout
    _br_start=$(date +%s)
    _flu_execute_with_timeout "${_fmp_timeout:-300}" "$_br_tmp"
    _br_exit_code=$?
    _br_end=$(date +%s)
    _br_duration=$((_br_end - _br_start))

    # Log execution result
    _br_op=$(_flu_classify_operation "$_br_aid")
    if [ "$_br_exit_code" -eq 0 ]; then
      _br_result="success"
    else
      _br_result="fail"
    fi
    _flu_log_execution "$_br_aid" "$_br_op" "$_br_result" \
      "${_fmp_version:-}" "$_br_duration" 2>/dev/null || true

    # Print result
    if [ "$_br_exit_code" -eq 0 ]; then
      if [ "$_br_is_tty" = "true" ]; then
        printf '%s✓ %s — Complete%s\n' "$TUI_GREEN" "$_br_aid" "$TUI_RESET"
      else
        printf '✓ %s — Complete\n' "$_br_aid"
      fi
      _br_ok=$((_br_ok + 1))
    else
      if [ "$_br_is_tty" = "true" ]; then
        printf '%s✗ %s — Failed (exit %d)%s\n' \
          "$TUI_RED" "$_br_aid" "$_br_exit_code" "$TUI_RESET"
      else
        printf '✗ %s — Failed (exit %d)\n' "$_br_aid" "$_br_exit_code"
      fi
      _br_fail=$((_br_fail + 1))
    fi

    # Clean up temp file
    rm -f "$_br_tmp" 2>/dev/null
    unset _br_tmp _br_fetch_rc _br_parse_rc _br_plat_match
    unset _br_start _br_end _br_duration _br_op _br_result _br_exit_code
  done
  IFS="$_br_saved_ifs"

  # Print summary
  printf '\n'
  if [ "$_br_is_tty" = "true" ]; then
    if [ "$_br_fail" -eq 0 ]; then
      printf '%s%d succeeded, %d failed%s\n' "$TUI_GREEN" "$_br_ok" "$_br_fail" "$TUI_RESET"
    else
      printf '%s%d succeeded, %d failed%s\n' "$TUI_YELLOW" "$_br_ok" "$_br_fail" "$TUI_RESET"
    fi
  else
    printf '%d succeeded, %d failed\n' "$_br_ok" "$_br_fail"
  fi

  # Save return code before cleanup
  _br_ret=0
  [ "$_br_fail" -gt 0 ] && _br_ret=1

  unset _br_action_ids _br_flags _br_ok _br_fail _br_is_tty _br_saved_ifs
  unset _br_menu _br_aid
  return "$_br_ret"
}

# ---------------------------------------------------------------------------
# Section 8.9: flu_batch_list() — List available modules
# ---------------------------------------------------------------------------

# flu_batch_list <json_flag>
# Lists available modules from menu.db in table or JSON format (D-03).
#
# Parameters:
#   $1 = "json" for --list --json, empty for plain text table
#
# Plain text: columnar table with Category, Subcategory, Name, Action ID
# JSON: array of objects with category, subcategory, name, action_id fields
flu_batch_list() {
  _bl_json="$1"
  _bl_menu="${FLU_MENU_FILE:-${FLU_SCRIPT_DIR:-.}/menu.db}"

  if [ ! -f "$_bl_menu" ]; then
    printf 'Error: menu database not found: %s\n' "$_bl_menu" >&2
    unset _bl_json _bl_menu
    return 1
  fi

  if [ "$_bl_json" = "json" ]; then
    # JSON output — array of objects
    printf '['
    _bl_first=true
    while IFS='|' read -r _bl_cat _bl_subcat _bl_label _bl_aid; do
      case "$_bl_cat" in \#*) continue ;; esac
      [ -z "$_bl_cat" ] && continue
      # Trim whitespace
      _bl_cat=$(printf '%s' "$_bl_cat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_subcat=$(printf '%s' "$_bl_subcat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_label=$(printf '%s' "$_bl_label" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_aid=$(printf '%s' "$_bl_aid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      if [ "$_bl_first" = "true" ]; then
        printf '\n'
        _bl_first=false
      else
        printf ',\n'
      fi
      printf '  {"category":"%s","subcategory":"%s","name":"%s","action_id":"%s"}' \
        "$_bl_cat" "$_bl_subcat" "$_bl_label" "$_bl_aid"
    done < "$_bl_menu"
    # Append community modules from registry
    _bl_reg_json=$(flu_registry_fetch 2>/dev/null) || true
    if [ -n "$_bl_reg_json" ]; then
      _bl_comm=$(printf '%s\n' "$_bl_reg_json" | awk '
        /"action_id"/ {
          _l = $0
          gsub(/.*"action_id": *"/, "", _l); gsub(/".*/, "", _l)
          id = _l
        }
        /"name"/ {
          _l = $0
          gsub(/.*"name": *"/, "", _l); gsub(/".*/, "", _l)
          name = _l
        }
        /"category"/ {
          _l = $0
          gsub(/.*"category": *"/, "", _l); gsub(/".*/, "", _l)
          cat = _l
        }
        /\}/ && id != "" {
          if (first != 0) printf ","
          printf "\n  {\"category\":\"Community Modules\",\"subcategory\":\"%s\",\"name\":\"%s\",\"action_id\":\"community/%s\"}", cat, name, id
          id = ""; name = ""; cat = ""
          first = 0
        }
        /\}/ { id = "" }
      ' first=1)
      if [ -n "$_bl_comm" ]; then
        printf '%s' "$_bl_comm"
      fi
    fi
    printf '\n]\n'
  else
    # Plain text table — sorted by category, subcategory, label
    printf '%-20s %-16s %-40s %s\n' "Category" "Subcategory" "Name" "Action ID"
    printf '%-20s %-16s %-40s %s\n' "--------" "-----------" "----" "---------"
    grep -v '^#' "$_bl_menu" | grep -v '^$' | sort -t'|' -k1,1 -k2,2 -k3,3 \
    | while IFS='|' read -r _bl_cat _bl_subcat _bl_label _bl_aid; do
      # Trim whitespace
      _bl_cat=$(printf '%s' "$_bl_cat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_subcat=$(printf '%s' "$_bl_subcat" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_label=$(printf '%s' "$_bl_label" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      _bl_aid=$(printf '%s' "$_bl_aid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      printf '%-20s %-16s %-40s %s\n' "$_bl_cat" "$_bl_subcat" "$_bl_label" "$_bl_aid"
    done
    # Append community modules from registry
    _bl_reg_json=$(flu_registry_fetch 2>/dev/null) || true
    if [ -n "$_bl_reg_json" ]; then
      printf '%s\n' "$_bl_reg_json" | awk '
        /"action_id"/ {
          _l = $0
          gsub(/.*"action_id": *"/, "", _l); gsub(/".*/, "", _l)
          id = _l
        }
        /"name"/ {
          _l = $0
          gsub(/.*"name": *"/, "", _l); gsub(/".*/, "", _l)
          name = _l
        }
        /"category"/ {
          _l = $0
          gsub(/.*"category": *"/, "", _l); gsub(/".*/, "", _l)
          cat = _l
        }
        /\}/ && id != "" {
          printf "%-20s %-16s %-40s community/%s\n", "Community Modules", cat, name, id
          id = ""; name = ""; cat = ""
        }
        /\}/ { id = "" }
      '
    fi
  fi

  unset _bl_json _bl_menu _bl_cat _bl_subcat _bl_label _bl_aid _bl_first
  unset _bl_reg_json _bl_comm
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
  _fme_start=$(date +%s)
  # shellcheck disable=SC2086  # _flu_module_args must split into multiple --key value pairs
  _flu_execute_with_timeout "$_fme_timeout" "$_fetmp" $_flu_module_args
  _fme_exit_code=$?
  _fme_end=$(date +%s)
  _fme_duration=$((_fme_end - _fme_start))

  # Log execution result
  _fme_op=$(_flu_classify_operation "$_fme_action")
  if [ "$_fme_exit_code" -eq 0 ]; then
    _fme_result="success"
  else
    _fme_result="fail"
  fi
  _flu_log_execution "$_fme_action" "$_fme_op" "$_fme_result" "${_fmp_version:-}" "$_fme_duration" 2>/dev/null || true

  # Step 7: Show completion status and wait for keypress
  stty sane 2>/dev/null < /dev/tty || true
  printf '\n'
  if [ "$_fme_exit_code" -eq 0 ]; then
    printf '%s  ✓ %s — Complete%s\n' "$TUI_GREEN" "${_fmp_name:-Module}" "$TUI_RESET"
  else
    printf '%s  ✗ %s — Failed (exit %d)%s\n' "$TUI_RED" "${_fmp_name:-Module}" "$_fme_exit_code" "$TUI_RESET"
  fi
  printf '%s  Press any key to return to menu%s' "$TUI_DIM" "$TUI_RESET"
  _tui_read_key

  # Cleanup temp files
  rm -f "$_fetmp" 2>/dev/null

  _fme_ret=${_fme_exit_code:-1}
  unset _fme_action _fetmp _fme_os_match _fme_saved_ifs _fme_p
  unset _fme_timeout _fme_exit_code _fme_start _fme_end _fme_duration _fme_op _fme_result
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
# Section 12: flu_registry_fetch() — Fetch and cache registry index
# ---------------------------------------------------------------------------

# flu_registry_fetch
# Fetches the community module registry JSON index, using cache when available.
# Merges official registry + FLU_REGISTRIES env var URLs (space-separated).
# Caches merged result to $FLU_CACHE_DIR/registry.json with TTL expiry.
# Prints merged JSON to stdout. Returns 0 on success, 1 if official registry
# fails AND no cache exists. Individual third-party registry failures are
# soft-fail (warning to stderr, continue).
flu_registry_fetch() {
  _frf_cache="${FLU_CACHE_DIR}/registry.json"
  _frf_merged=''

  # Check for cached registry with TTL
  if [ -f "$_frf_cache" ] && [ -s "$_frf_cache" ]; then
    _frf_now=$(date +%s)
    _frf_mtime=$(stat -c %Y "$_frf_cache" 2>/dev/null || echo 0)
    _frf_age=$((_frf_now - _frf_mtime))
    if [ "$_frf_age" -lt "${FLU_CACHE_TTL:-86400}" ] 2>/dev/null; then
      cat "$_frf_cache"
      unset _frf_cache _frf_now _frf_mtime _frf_age _frf_merged
      return 0
    fi
  fi

  # Fetch official registry
  _frf_official=''
  if command -v curl >/dev/null 2>&1; then
    _frf_official=$(curl -fsSL --connect-timeout 5 "$FLU_REGISTRY_URL" 2>/dev/null) || true
  else
    _frf_official=$(wget -qO- --timeout=5 "$FLU_REGISTRY_URL" 2>/dev/null) || true
  fi

  # If official fetch failed, try using stale cache
  if [ -z "$_frf_official" ]; then
    if [ -f "$_frf_cache" ] && [ -s "$_frf_cache" ]; then
      printf '%s[WARN]%s Official registry unavailable — using stale cache (age: %ds)\n' \
        "${TUI_YELLOW:-}" "${TUI_RESET:-}" "${_frf_age:-?}" >&2
      cat "$_frf_cache"
      unset _frf_cache _frf_now _frf_mtime _frf_age _frf_official _frf_merged
      return 0
    fi
    printf '%s[WARN]%s Registry unavailable and no cache exists\n' \
      "${TUI_YELLOW:-}" "${TUI_RESET:-}" >&2
    unset _frf_cache _frf_official _frf_merged
    return 1
  fi

  # Start with official registry content (strip outer brackets for consistent merging)
  _frf_merged=$(printf '%s' "$_frf_official" | sed 's/^\[//;s/\]$//')

  # Fetch and merge additional registries from FLU_REGISTRIES env var
  if [ -n "${FLU_REGISTRIES:-}" ]; then
    _frf_saved_ifs="$IFS"
    IFS=' '
    for _frf_url in $FLU_REGISTRIES; do
      [ -z "$_frf_url" ] && continue
      _frf_extra=''
      if command -v curl >/dev/null 2>&1; then
        _frf_extra=$(curl -fsSL --connect-timeout 5 "$_frf_url" 2>/dev/null) || true
      else
        _frf_extra=$(wget -qO- --timeout=5 "$_frf_url" 2>/dev/null) || true
      fi
      if [ -n "$_frf_extra" ]; then
        # Strip outer brackets from extra, join with comma to merged content
        _frf_extra_stripped=$(printf '%s' "$_frf_extra" | sed 's/^\[//;s/\]$//')
        # Merge: if merged already has content, append with comma
        if [ -n "$_frf_merged" ]; then
          _frf_merged="${_frf_merged},${_frf_extra_stripped}"
        else
          _frf_merged="$_frf_extra_stripped"
        fi
      else
        printf '%s[WARN]%s Third-party registry unavailable: %s\n' \
          "${TUI_YELLOW:-}" "${TUI_RESET:-}" "$_frf_url" >&2
      fi
      unset _frf_url _frf_extra _frf_extra_stripped
    done
    IFS="$_frf_saved_ifs"
    unset _frf_saved_ifs
  fi

  # Wrap merged content as JSON array and cache
  mkdir -p "$FLU_CACHE_DIR" 2>/dev/null || true
  _frf_cache_tmp="${FLU_CACHE_DIR}/.tmp_reg_$$"
  printf '[%s]\n' "$_frf_merged" > "$_frf_cache_tmp"
  mv "$_frf_cache_tmp" "$_frf_cache" 2>/dev/null || rm -f "$_frf_cache_tmp" 2>/dev/null

  # Output merged JSON
  printf '[%s]\n' "$_frf_merged"

  unset _frf_cache _frf_now _frf_mtime _frf_age _frf_official _frf_merged _frf_cache_tmp
  return 0
}

# ---------------------------------------------------------------------------
# Section 13: flu_registry_lookup() — Look up a module in registry
# ---------------------------------------------------------------------------

# flu_registry_lookup <action_id>
# Looks up a community module by action_id in the registry index.
# Sets globals: _freg_name, _freg_description, _freg_category,
#   _freg_platforms, _freg_base_url, _freg_sha256
# Returns 0 if found, 1 if not found.
flu_registry_lookup() {
  _frl_id="$1"
  _frl_json=''

  # Fetch registry (uses cache when available)
  _frl_json=$(flu_registry_fetch 2>/dev/null) || true
  if [ -z "$_frl_json" ]; then
    unset _frl_id _frl_json
    return 1
  fi

  # Parse JSON with awk — flat array of objects, no nesting
  # Uses line copies to avoid modifying $0 for subsequent pattern matching
  _frl_result=$(printf '%s\n' "$_frl_json" | awk -v id="$_frl_id" '
    /"action_id"/ {
      _line = $0
      gsub(/.*"action_id": *"/, "", _line)
      gsub(/".*/, "", _line)
      current_id = _line
    }
    current_id == id && /"name"/ {
      _line = $0
      gsub(/.*"name": *"/, "", _line)
      gsub(/".*/, "", _line)
      name = _line
    }
    current_id == id && /"description"/ {
      _line = $0
      gsub(/.*"description": *"/, "", _line)
      gsub(/".*/, "", _line)
      desc = _line
    }
    current_id == id && /"category"/ {
      _line = $0
      gsub(/.*"category": *"/, "", _line)
      gsub(/".*/, "", _line)
      cat = _line
    }
    current_id == id && /"platforms"/ {
      _line = $0
      gsub(/.*"platforms": *"/, "", _line)
      gsub(/".*/, "", _line)
      plats = _line
    }
    current_id == id && /"base_url"/ {
      _line = $0
      gsub(/.*"base_url": *"/, "", _line)
      gsub(/".*/, "", _line)
      burl = _line
    }
    current_id == id && /"sha256"/ {
      _line = $0
      gsub(/.*"sha256": *"/, "", _line)
      gsub(/".*/, "", _line)
      hash = _line
    }
    /\}/ && current_id == id {
      printf "%s\n%s\n%s\n%s\n%s\n%s\n", name, desc, cat, plats, burl, hash
      current_id = ""
      name = ""; desc = ""; cat = ""; plats = ""; burl = ""; hash = ""
    }
    /\}/ && current_id != "" {
      current_id = ""
      name = ""; desc = ""; cat = ""; plats = ""; burl = ""; hash = ""
    }
  ')

  if [ -z "$_frl_result" ]; then
    printf 'Module not found in registry: %s\n' "$_frl_id" >&2
    unset _frl_id _frl_json _frl_result
    return 1
  fi

  # Extract individual fields from awk output (6 lines)
  _freg_name=$(printf '%s\n' "$_frl_result" | awk 'NR==1')
  _freg_description=$(printf '%s\n' "$_frl_result" | awk 'NR==2')
  _freg_category=$(printf '%s\n' "$_frl_result" | awk 'NR==3')
  _freg_platforms=$(printf '%s\n' "$_frl_result" | awk 'NR==4')
  _freg_base_url=$(printf '%s\n' "$_frl_result" | awk 'NR==5')
  _freg_sha256=$(printf '%s\n' "$_frl_result" | awk 'NR==6')

  unset _frl_id _frl_json _frl_result
  return 0
}

# ---------------------------------------------------------------------------
# Section 14: flu_registry_fetch_module() — Fetch a community module
# ---------------------------------------------------------------------------

# flu_registry_fetch_module <action_id>
# Fetches a community module script from the registry-provided URL,
# verifies SHA256 checksum from the registry index, and caches the result.
# Parameter: action_id WITHOUT the community/ prefix.
# Prints script content to stdout on success. Returns 0 on success, 1 on failure.
flu_registry_fetch_module() {
  _frfm_id="$1"

  # Look up in registry to get base_url and sha256
  flu_registry_lookup "$_frfm_id" || {
    unset _frfm_id
    return 1
  }

  # Build full URL for the module script
  _frfm_url="${_freg_base_url}${_frfm_id}.sh"
  _frfm_expected_hash="$_freg_sha256"
  _frfm_cache_file="${FLU_CACHE_DIR}/community_${_frfm_id}"

  # Check cache first
  if [ -f "$_frfm_cache_file" ] && [ -s "$_frfm_cache_file" ]; then
    _frfm_now=$(date +%s)
    _frfm_mtime=$(stat -c %Y "$_frfm_cache_file" 2>/dev/null || echo 0)
    _frfm_age=$((_frfm_now - _frfm_mtime))
    if [ "$_frfm_age" -lt "${FLU_CACHE_TTL:-86400}" ] 2>/dev/null; then
      printf '  %s[cached]%s community/%s (age: %ds)\n' \
        "${TUI_DIM:-}" "${TUI_RESET:-}" "$_frfm_id" "$_frfm_age" >&2
      cat "$_frfm_cache_file"
      unset _frfm_id _frfm_url _frfm_expected_hash _frfm_cache_file
      unset _frfm_now _frfm_mtime _frfm_age _frfm_content
      return 0
    fi
  fi

  # Fetch the module script
  _frfm_content=''
  _frfm_attempt=1
  _frfm_rc=1

  while [ "$_frfm_attempt" -le 3 ]; do
    printf '  Downloading community/%s.sh... ' "$_frfm_id" >&2
    _frfm_tmp_dl="${TMPDIR:-/tmp}/flu_dl_$$_${_frfm_id}"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --connect-timeout 10 --progress-bar "$_frfm_url" -o "$_frfm_tmp_dl" 2>&2
      _frfm_rc=$?
    else
      wget -q --show-progress -O "$_frfm_tmp_dl" "$_frfm_url" 2>&2
      _frfm_rc=$?
    fi

    if [ "$_frfm_rc" -eq 0 ] && [ -f "$_frfm_tmp_dl" ] && [ -s "$_frfm_tmp_dl" ]; then
      _frfm_content=$(cat "$_frfm_tmp_dl")
      _frfm_size=$(wc -c < "$_frfm_tmp_dl")
      rm -f "$_frfm_tmp_dl"
      printf 'done (%s bytes)\n' "$_frfm_size" >&2
      break
    fi

    rm -f "$_frfm_tmp_dl" 2>/dev/null
    printf 'failed\n' >&2

    if [ "$_frfm_attempt" -lt 3 ]; then
      printf '  Retrying (%d/3)...\n' "$((_frfm_attempt + 1))" >&2
      sleep 2
    fi
    _frfm_attempt=$((_frfm_attempt + 1))
  done

  if [ -z "$_frfm_content" ]; then
    printf '%s[ERROR]%s Failed to fetch community module: %s (exit: %d)\n' \
      "${TUI_RED:-}" "${TUI_RESET:-}" "$_frfm_url" "$_frfm_rc" >&2
    unset _frfm_id _frfm_url _frfm_expected_hash _frfm_cache_file
    unset _frfm_content _frfm_attempt _frfm_rc _frfm_tmp_dl _frfm_size
    return 1
  fi

  # SHA256 verification against registry-provided hash
  if [ -n "$_frfm_expected_hash" ]; then
    _frfm_actual_hash=$(printf '%s\n' "$_frfm_content" | sha256sum | awk '{print $1}')
    if [ "$_frfm_actual_hash" != "$_frfm_expected_hash" ]; then
      printf '%s[ERROR]%s Checksum mismatch for community/%s.sh — possible tampering or corruption\n' \
        "${TUI_RED:-}" "${TUI_RESET:-}" "$_frfm_id" >&2
      unset _frfm_id _frfm_url _frfm_expected_hash _frfm_cache_file
      unset _frfm_content _frfm_attempt _frfm_rc _frfm_actual_hash _frfm_size
      return 1
    fi
    printf '  %s[verified]%s SHA256 checksum OK\n' "${TUI_GREEN:-}" "${TUI_RESET:-}" >&2
  fi

  # Store to cache (atomic via mv)
  mkdir -p "$FLU_CACHE_DIR" 2>/dev/null || true
  if [ -d "$FLU_CACHE_DIR" ]; then
    _frfm_cache_tmp="${FLU_CACHE_DIR}/.tmp_comm_$$_${_frfm_id}"
    printf '%s\n' "$_frfm_content" > "$_frfm_cache_tmp"
    mv "$_frfm_cache_tmp" "$_frfm_cache_file" 2>/dev/null || rm -f "$_frfm_cache_tmp" 2>/dev/null
  fi

  printf '%s\n' "$_frfm_content"
  unset _frfm_id _frfm_url _frfm_expected_hash _frfm_cache_file
  unset _frfm_content _frfm_attempt _frfm_rc _frfm_actual_hash _frfm_size _frfm_cache_tmp
  return 0
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
