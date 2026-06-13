#!/usr/bin/env sh
# @name: Install gsd-browser (Open GSD)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# GSD Browser is a native Rust CLI for Chrome/Chromium automation via
# CDP. Persistent daemon, 90+ commands, and 50+ MCP tools for AI agent
# integration. Features MCP server mode, versioned element refs, and a
# live human-in-the-loop viewer.
# Documentation: https://docs.opengsd.net/
# Repository: https://github.com/open-gsd
# Install: npm install -g @opengsd/gsd-browser
# Requires: Node.js LTS (auto-installed if missing).

set -eu

# ──────────────
# Auto-install Node.js LTS (NVM) if npm is missing
# ──────────────
_ensure_node() {
    if command -v npm >/dev/null 2>&1; then
        return 0
    fi

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    if command -v npm >/dev/null 2>&1; then
        return 0
    fi

    printf 'Node.js not found — installing NVM + Node LTS...\n'

    if ! command -v nvm >/dev/null 2>&1; then
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh -o /tmp/nvm-install.sh || { printf 'NVM download failed\n' >&2; return 1; }
        elif command -v wget >/dev/null 2>&1; then
            wget -qO /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh || { printf 'NVM download failed\n' >&2; return 1; }
        else
            printf 'curl or wget required to install Node.js\n' >&2
            return 1
        fi
        bash /tmp/nvm-install.sh || { rm -f /tmp/nvm-install.sh; printf 'NVM install failed\n' >&2; return 1; }
        rm -f /tmp/nvm-install.sh
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    fi

    if ! command -v node >/dev/null 2>&1; then
        nvm install --lts || { printf 'Node LTS install failed\n' >&2; return 1; }
    fi

    if ! command -v npm >/dev/null 2>&1; then
        printf 'npm still not available after install\n' >&2
        return 1
    fi
}

_ensure_node || exit 1

if npm list -g @opengsd/gsd-browser >/dev/null 2>&1; then
    _ver=$(gsd-browser --version 2>/dev/null || printf 'installed')
    printf 'gsd-browser already installed [%s]\n' "$_ver"
    printf 'Updating...\n'
    npm update -g @opengsd/gsd-browser || true
else
    printf 'Installing gsd-browser (Open GSD)...\n'
    if npm install -g @opengsd/gsd-browser; then
        if npm list -g @opengsd/gsd-browser >/dev/null 2>&1; then
            printf 'gsd-browser installed successfully\n'
        else
            printf 'gsd-browser install failed (not found after npm install)\n' >&2
            exit 1
        fi
    else
        printf 'gsd-browser install failed\n' >&2
        exit 1
    fi
fi
