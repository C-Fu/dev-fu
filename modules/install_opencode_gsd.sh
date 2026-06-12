#!/usr/bin/env sh
# @name: Install OpenCode + GSD (Rokicool) + OpenChamber
# @params:
# @platforms: linux, darwin
# @version: 1.1.0
# @deps: npm
# @timeout: 600
#
# Installs OpenCode, GSD (Rokicool), and OpenChamber via npm.
# Requires Node.js and npm to be available on the system.

set -eu

# Check npm is available
if ! command -v npm >/dev/null 2>&1; then
    printf 'npm is required to install OpenCode + GSD (Rokicool) + OpenChamber.\n' >&2
    printf 'Please install Node.js first (use "Install NVM + Node LTS" from the Languages menu).\n' >&2
    exit 1
fi

# Check which components are already installed
need_opencode=0
need_gsd=0
need_openchamber=0

if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
    opencode_ver=$(opencode --version 2>/dev/null || printf 'installed')
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

printf '\nInstalling selected components...\n'
install_errors=0

# Install OpenCode
if [ "$need_opencode" = "1" ]; then
    printf 'Installing OpenCode...\n'
    if npm install -g opencode-ai && npm list -g opencode-ai >/dev/null 2>&1; then
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
