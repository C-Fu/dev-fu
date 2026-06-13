#!/usr/bin/env sh
# @name: Install all Open GSD tools
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 1800
#
# Installs the full Open GSD suite — gsd-core (spec-driven workflow
# engine), gsd-pi (autonomous local coding agent), and gsd-browser
# (CDP browser automation) — in one go. Node.js LTS is auto-installed
# if missing. Documentation: https://docs.opengsd.net/
# Repository: https://github.com/open-gsd

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

_rc=0

printf '\n=== 1/3: gsd-core ===\n'
if npx --yes @opengsd/gsd-core@latest; then
    printf 'gsd-core installed successfully\n'
else
    printf 'gsd-core install failed\n' >&2
    _rc=1
fi

printf '\n=== 2/3: gsd-pi ===\n'
if npx --yes @opengsd/gsd-pi@latest; then
    printf 'gsd-pi installed successfully\n'
else
    printf 'gsd-pi install failed\n' >&2
    _rc=1
fi

printf '\n=== 3/3: gsd-browser ===\n'
if npm install -g @opengsd/gsd-browser; then
    if npm list -g @opengsd/gsd-browser >/dev/null 2>&1; then
        printf 'gsd-browser installed successfully\n'
    else
        printf 'gsd-browser install failed (not found after npm install)\n' >&2
        _rc=1
    fi
else
    printf 'gsd-browser install failed\n' >&2
    _rc=1
fi

if [ "$_rc" = "0" ]; then
    printf '\nAll Open GSD tools installed successfully\n'
else
    printf '\nSome Open GSD installs failed — see messages above\n' >&2
fi
exit "$_rc"
