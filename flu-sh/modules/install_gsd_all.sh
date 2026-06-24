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

# Auto-detect package manager when not provided by flu.sh
if [ -z "${FLU_PKG_MGR:-}" ]; then
    if      command -v apt-get >/dev/null 2>&1; then FLU_PKG_MGR="apt"
    elif    command -v apk     >/dev/null 2>&1; then FLU_PKG_MGR="apk"
    elif    command -v dnf     >/dev/null 2>&1; then FLU_PKG_MGR="dnf"
    elif    command -v pacman  >/dev/null 2>&1; then FLU_PKG_MGR="pacman"
    elif    command -v zypper  >/dev/null 2>&1; then FLU_PKG_MGR="zypper"
    elif    command -v brew    >/dev/null 2>&1; then FLU_PKG_MGR="brew"
    fi
fi

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

_pkg_install() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get install -y "$@" ;;
        apk)    _maybe_sudo apk add "$@" ;;
        dnf)    _maybe_sudo dnf install -y "$@" ;;
        pacman) _maybe_sudo pacman -S --noconfirm "$@" ;;
        zypper) _maybe_sudo zypper install -y "$@" ;;
        brew)   brew install "$@" ;;
        *)      printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2; return 1 ;;
    esac
}

_is_musl() {
    [ "${FLU_PKG_MGR:-}" = "apk" ]
}

# Open GSD CLI packages use #!/usr/bin/env bash shebangs and cannot run on
# Alpine/musl systems where bash is not installed. We respect the "no bash on
# Alpine" constraint by failing early with a clear, actionable message.
if _is_musl && ! command -v bash >/dev/null 2>&1; then
    printf 'Open GSD tools require bash, which is not installed on this Alpine/musl system.\n' >&2
    printf 'Install bash manually (apk add bash) or use a glibc-based distribution.\n' >&2
    exit 1
fi

# ──────────────
# Auto-install Node.js LTS (NVM) if npm/npx are missing
# ──────────────
_ensure_node() {
    if command -v npm >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
        return 0
    fi

    # Alpine/musl path — native package install (NVM incompatible with musl libc)
    if _is_musl; then
        if command -v node >/dev/null 2>&1; then
            printf 'Node.js already installed: %s\n' "$(node --version)"
            return 0
        fi
        printf 'Node.js not found — installing via apk...\n'
        _pkg_install nodejs npm || { printf 'Node.js install failed\n' >&2; return 1; }
        printf 'Node.js %s installed successfully\n' "$(node --version)"
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
