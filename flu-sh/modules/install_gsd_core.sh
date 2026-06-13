#!/usr/bin/env sh
# @name: Install gsd-core (Open GSD)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# GSD Core is a spec-driven development framework that sits on top of any
# AI coding runtime (Claude Code, OpenCode, Gemini CLI, Cursor, etc.).
# Runs a five-step phase loop — Discuss, Plan, Execute, Verify, Ship —
# with 65+ slash commands and persistent .planning/ artifacts.
# Documentation: https://docs.opengsd.net/
# Repository: https://github.com/open-gsd
# Install: npx @opengsd/gsd-core@latest

set -eu

# ──────────────
# Auto-install Node.js LTS (NVM) if npm/npx are missing
# ──────────────
_ensure_node() {
    if command -v npm >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
        return 0
    fi

    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" 2>/dev/null || true

    if command -v npm >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
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

    if ! command -v npm >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
        printf 'npm/npx still not available after install\n' >&2
        return 1
    fi
}

_ensure_node || exit 1

printf 'Installing gsd-core (Open GSD)...\n'
if npx --yes @opengsd/gsd-core@latest; then
    printf 'gsd-core installed successfully\n'
else
    printf 'gsd-core install failed\n' >&2
    exit 1
fi
