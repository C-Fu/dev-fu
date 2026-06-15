#!/usr/bin/env sh
# @name: Install Rust
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 600
#
# Installs Rust (rustup, rustc, cargo) via the official rustup installer.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

# Auto-detect package manager when not provided by flu.sh (used for rustup dep fallback)
if [ -z "${FLU_PKG_MGR:-}" ]; then
    if      command -v apt-get >/dev/null 2>&1; then FLU_PKG_MGR="apt"
    elif    command -v apk     >/dev/null 2>&1; then FLU_PKG_MGR="apk"
    elif    command -v dnf     >/dev/null 2>&1; then FLU_PKG_MGR="dnf"
    elif    command -v pacman  >/dev/null 2>&1; then FLU_PKG_MGR="pacman"
    elif    command -v zypper  >/dev/null 2>&1; then FLU_PKG_MGR="zypper"
    elif    command -v brew    >/dev/null 2>&1; then FLU_PKG_MGR="brew"
    fi
fi

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if command -v rustc >/dev/null 2>&1 && rustc --version >/dev/null 2>&1; then
    printf 'Rust already installed: %s\n' "$(rustc --version)"
    exit 0
fi

if command -v rustup >/dev/null 2>&1; then
    printf 'Detected rustup without a default toolchain — running "rustup default stable"...\n'
    if rustup default stable 2>&1; then
        if [ -f "$HOME/.cargo/env" ]; then
            . "$HOME/.cargo/env"
        fi
        if command -v rustc >/dev/null 2>&1 && rustc --version >/dev/null 2>&1; then
            printf 'Rust installed: %s\n' "$(rustc --version)"
            exit 0
        fi
    fi
    printf 'rustup default stable did not produce a working rustc — falling back to rustup-init...\n' >&2
fi

if command -v curl >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh || { printf 'Rust download failed\n' >&2; exit 1; }
elif command -v wget >/dev/null 2>&1; then
    wget -qO /tmp/rustup.sh https://sh.rustup.rs || { printf 'Rust download failed\n' >&2; exit 1; }
else
    printf 'No download tool available (curl or wget required)\n' >&2
    exit 1
fi

sh /tmp/rustup.sh -y || { rm -f /tmp/rustup.sh; printf 'Rust install failed\n' >&2; exit 1; }
rm -f /tmp/rustup.sh

if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

if ! command -v rustc >/dev/null 2>&1 || ! rustc --version >/dev/null 2>&1; then
    printf 'Rust install completed but rustc is not usable. Run "rustup default stable" manually.\n' >&2
    exit 1
fi

printf 'Rust installed: %s\n' "$(rustc --version)"
