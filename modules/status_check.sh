#!/usr/bin/env sh
# @name: Status Check
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 120
#
# Checks installation status and versions of all supported
# developer tools. Outputs a formatted status report.

set -eu

_SC_GREEN='\033[32m'
_SC_RED='\033[31m'
_SC_RESET='\033[0m'

if [ -s "${HOME}/.nvm/nvm.sh" ]; then
    . "${HOME}/.nvm/nvm.sh" 2>/dev/null || true
fi

_pad_name() {
    _pn_name="$1"
    _pn_pad="            "
    _pn_out="${_pn_name}${_pn_pad}"
    printf '%s' "$_pn_out" | awk '{print substr($0,1,12)}'
    unset _pn_name _pn_pad _pn_out
}

check_cmd_version() {
    _name="$1"
    _cmd="$2"
    _flag="$3"
    _padded=$(_pad_name "$_name")
    if command -v "$_cmd" >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            _ver=$(echo "y" | timeout 5 "$_cmd" $_flag 2>/dev/null | head -1 | tr -s ' ' | awk '{print $1, $2}')
        else
            _ver=$(echo "y" | "$_cmd" $_flag 2>/dev/null | head -1 | tr -s ' ' | awk '{print $1, $2}')
        fi
        printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_padded" "${_ver:-installed}"
    else
        printf '  %b[MISS]%b %s : NOT installed\n' "$_SC_RED" "$_SC_RESET" "$_padded"
    fi
}

printf 'Status Check — Developer Tools\n'
printf '==============================\n'
printf '\n'

if [ "${FLU_OS:-}" = "linux" ]; then
    _distro="${FLU_DISTRO:-unknown}"
    _kernel=$(uname -r 2>/dev/null || printf 'unknown')
    _arch="${FLU_ARCH:-$(uname -m)}"
elif [ "${FLU_OS:-}" = "darwin" ]; then
    _distro="macOS"
    _kernel=$(uname -r 2>/dev/null || printf 'unknown')
    _arch="${FLU_ARCH:-$(uname -m)}"
else
    _distro=$(uname -s 2>/dev/null || printf 'unknown')
    _kernel=$(uname -r 2>/dev/null || printf 'unknown')
    _arch=$(uname -m 2>/dev/null || printf 'unknown')
fi
printf '  System:  %s | %s | %s\n' "$_distro" "$_kernel" "$_arch"
printf '\n'

# Languages & Runtimes
printf '%s\n' '--- Languages & Runtimes ---'
check_cmd_version "Go" "go" "version"
check_cmd_version "Rustc" "rustc" "--version"
check_cmd_version "Cargo" "cargo" "--version"
check_cmd_version "Bun" "bun" "--version"

# NVM
_nvm_padded=$(_pad_name "NVM")
if command -v nvm >/dev/null 2>&1; then
    _nvm_ver=$(nvm --version 2>/dev/null || printf 'installed')
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_nvm_padded" "$_nvm_ver"
else
    printf '  %b[MISS]%b %s : NOT installed\n' "$_SC_RED" "$_SC_RESET" "$_nvm_padded"
fi

check_cmd_version "Node.js" "node" "--version"
check_cmd_version "Python" "python3" "--version"
check_cmd_version "pip" "pip3" "--version"
check_cmd_version "pipx" "pipx" "--version"
check_cmd_version "uv" "uv" "--version"
check_cmd_version "PHP" "php" "-v"
check_cmd_version "Yarn" "yarn" "--version"
check_cmd_version "Composer" "composer" "--version"

printf '\n'
printf '%s\n' '--- Tools ---'
check_cmd_version "Docker" "docker" "--version"
check_cmd_version "Tailscale" "tailscale" "version"

# OpenChamber
_oc_padded=$(_pad_name "OpenChamber")
if command -v openchamber >/dev/null 2>&1; then
    _oc_ver=$(openchamber --version 2>/dev/null || printf 'installed')
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_oc_padded" "$_oc_ver"
elif npm list -g @openchamber/web >/dev/null 2>&1; then
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_oc_padded" "npm global"
else
    printf '  %b[MISS]%b %s : NOT installed\n' "$_SC_RED" "$_SC_RESET" "$_oc_padded"
fi

# OpenCode
_op_padded=$(_pad_name "OpenCode")
if command -v opencode >/dev/null 2>&1; then
    _op_ver=$(opencode --version 2>/dev/null || printf 'installed')
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_op_padded" "$_op_ver"
elif npm list -g opencode-ai >/dev/null 2>&1; then
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_op_padded" "npm global"
else
    printf '  %b[MISS]%b %s : NOT installed\n' "$_SC_RED" "$_SC_RESET" "$_op_padded"
fi

# GSD
_gsd_padded=$(_pad_name "GSD")
_gsd_found=0
_gsd_ver=""
if command -v gsd-opencode >/dev/null 2>&1; then
    _gsd_found=1
    _gsd_ver=$(gsd-opencode --version 2>/dev/null | head -1 || printf 'installed')
elif npm list -g gsd-opencode >/dev/null 2>&1; then
    _gsd_found=1
    _gsd_ver="npm global"
elif npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
    _gsd_found=1
    _gsd_ver=$(npx --yes gsd-opencode --version 2>/dev/null | head -1)
fi
if [ "$_gsd_found" = "1" ]; then
    printf '  %b[OK]%b   %s : %s\n' "$_SC_GREEN" "$_SC_RESET" "$_gsd_padded" "${_gsd_ver:-installed}"
else
    printf '  %b[MISS]%b %s : NOT installed\n' "$_SC_RED" "$_SC_RESET" "$_gsd_padded"
fi

printf '\n'
printf '%s\n' '--- Utilities ---'
check_cmd_version "curl" "curl" "--version"
check_cmd_version "wget" "wget" "--version"
check_cmd_version "git" "git" "--version"
check_cmd_version "jq" "jq" "--version"
check_cmd_version "fzf" "fzf" "--version"
check_cmd_version "zoxide" "zoxide" "--version"
check_cmd_version "bat" "bat" "--version"
check_cmd_version "eza" "eza" "--version"
check_cmd_version "fd" "fd" "--version"
check_cmd_version "rg" "rg" "--version"

printf '\n'
printf '==============================\n'
printf 'Status check complete.\n'
