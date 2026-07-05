#!/usr/bin/env sh
# @name: Install OpenCode + GSD (Rokicool) + OpenChamber
# @params:
# @platforms: linux, darwin
# @version: 1.2.0
# @deps: curl or npm
# @timeout: 600
#
# Installs OpenCode, GSD (Rokicool), and OpenChamber.
# OpenCode uses the official installer (preferred) with npm fallback,
# because the opencode-ai npm wrapper has a buggy postinstall on some
# ARM64 Linux systems (e.g. Raspberry Pi OS with glibc).
# GSD and OpenChamber are installed via npm.

set -eu

_OFFICIAL_BIN="$HOME/.opencode/bin/opencode"

_opencode_works() {
    if [ -x "$_OFFICIAL_BIN" ] && "$_OFFICIAL_BIN" --version >/dev/null 2>&1; then
        return 0
    fi
    if command -v opencode >/dev/null 2>&1 && opencode --version >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

_install_opencode() {
    if command -v curl >/dev/null 2>&1; then
        printf 'Installing OpenCode via official installer...\n'
        if curl -fsSL https://opencode.ai/install | sh && _opencode_works; then
            return 0
        fi
        printf 'Official installer failed, trying npm...\n'
    fi
    if command -v npm >/dev/null 2>&1 && npm --version >/dev/null 2>&1; then
        printf 'Installing OpenCode via npm...\n'
        if npm install -g opencode-ai && _opencode_works; then
            return 0
        fi
    fi
    return 1
}

# Check which components are already installed
need_opencode=0
need_gsd=0
need_openchamber=0

if _opencode_works; then
    opencode_ver=$( ( [ -x "$_OFFICIAL_BIN" ] && "$_OFFICIAL_BIN" --version 2>/dev/null) || (command -v opencode >/dev/null 2>&1 && opencode --version 2>/dev/null) || printf 'installed' )
    printf 'OpenCode already installed [%s]\n' "$opencode_ver"
else
    printf 'OpenCode will be installed\n'
    need_opencode=1
fi

if npm list -g gsd-opencode >/dev/null 2>&1; then
    gsd_ver=$(gsd-opencode --version 2>/dev/null | head -1 || printf 'installed')
    printf 'GSD (Rokicool) already installed [%s]\n' "$gsd_ver"
else
    printf 'GSD (Rokicool) will be installed\n'
    need_gsd=1
fi

if command -v openchamber >/dev/null 2>&1 || npm list -g @openchamber/web >/dev/null 2>&1; then
    oc_ver=$(openchamber --version 2>/dev/null || printf 'installed')
    printf 'OpenChamber already installed [%s]\n' "$oc_ver"
else
    printf 'OpenChamber will be installed\n'
    need_openchamber=1
fi

# All already installed
if [ "$need_opencode" = "0" ] && [ "$need_gsd" = "0" ] && [ "$need_openchamber" = "0" ]; then
    printf '\nAll components are already installed.\n'
    exit 0
fi

# Check npm is available (needed for GSD and OpenChamber)
if [ "$need_gsd" = "1" ] || [ "$need_openchamber" = "1" ]; then
    if ! command -v npm >/dev/null 2>&1 || ! npm --version >/dev/null 2>&1; then
        printf 'npm is required to install GSD (Rokicool) and OpenChamber.\n' >&2
        printf 'Please install Node.js first (use "Install NVM + Node LTS" from the Languages menu).\n' >&2
        exit 1
    fi
fi

printf '\nInstalling selected components...\n'
install_errors=0

# Install OpenCode
if [ "$need_opencode" = "1" ]; then
    if _install_opencode; then
        printf 'OpenCode installed successfully\n'
    else
        printf 'OpenCode install failed\n' >&2
        install_errors=$((install_errors + 1))
    fi
fi

# Install GSD (Rokicool)
if [ "$need_gsd" = "1" ]; then
    printf 'Installing GSD (Rokicool)...\n'
    if npm install -g gsd-opencode && npm list -g gsd-opencode >/dev/null 2>&1; then
        printf 'GSD (Rokicool) installed successfully\n'
    else
        printf 'GSD (Rokicool) install failed\n' >&2
        install_errors=$((install_errors + 1))
    fi
fi

# Ensure gsd-sdk (bundled with gsd-opencode) is on PATH
if command -v npm >/dev/null 2>&1; then
    _npm_prefix=$(npm prefix -g 2>/dev/null || true)
    if [ -n "$_npm_prefix" ] && [ -f "${_npm_prefix}/bin/gsd-sdk" ]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "${_npm_prefix}/bin/gsd-sdk" "$HOME/.local/bin/gsd-sdk"
        case ":${PATH}:" in
            *":$HOME/.local/bin:"*) ;;
            *)
                printf '⚠ %s is not in your PATH.\n' "$HOME/.local/bin"
                printf '  Add it with: export PATH="%s:$PATH"\n' "$HOME/.local/bin"
                ;;
        esac
    fi
fi

# Install OpenChamber
if [ "$need_openchamber" = "1" ]; then
    printf 'Installing OpenChamber...\n'
    if npm install -g @openchamber/web && npm list -g @openchamber/web >/dev/null 2>&1; then
        printf 'OpenChamber installed successfully\n'
    else
        printf 'OpenChamber install failed\n' >&2
        install_errors=$((install_errors + 1))
    fi
fi

printf '\n'
if [ "$install_errors" -gt 0 ]; then
    printf '%d component(s) failed to install.\n' "$install_errors" >&2
    exit 1
else
    printf 'All components installed successfully.\n'
fi
