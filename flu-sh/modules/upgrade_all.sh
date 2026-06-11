#!/usr/bin/env sh
# @name: Upgrade All Tools
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 900
#
# Batch-upgrades all installed developer tools.
# Handles package-manager-based tools and non-package-manager tools
# (Rust via rustup, Node via NVM, Bun via installer, etc.).
# Skips tools that are not installed.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo "$@"
    fi
}

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

_pkg_update() {
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get update ;;
        apk)    _maybe_sudo apk update ;;
        dnf)    _maybe_sudo dnf check-update || true ;;
        pacman) _maybe_sudo pacman -Sy ;;
        zypper) _maybe_sudo zypper refresh ;;
        brew)   brew update ;;
    esac
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

# Source NVM if available
if [ -s "${HOME}/.nvm/nvm.sh" ]; then
    . "${HOME}/.nvm/nvm.sh" 2>/dev/null || true
fi

printf 'Upgrade All Tools\n'
printf '=================\n'
printf '\n'

upgraded=0
failures=0

# ─── Docker ────────────────────────
if command -v docker >/dev/null 2>&1; then
    printf 'Upgrading Docker...\n'
    _pkg_update >/dev/null 2>&1 || true
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _maybe_sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
        apk)    _maybe_sudo apk upgrade docker 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
        dnf)    _maybe_sudo dnf upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
        pacman) _maybe_sudo pacman -Syu --noconfirm docker 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
        zypper) _maybe_sudo zypper update -y docker 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
        brew)   brew upgrade docker 2>/dev/null || { printf '  Docker upgrade failed\n' >&2; failures=$((failures + 1)); } ;;
    esac
    upgraded=1
    printf '  Docker: %s\n' "$(docker --version 2>/dev/null | head -1)"
fi

# ─── Go ────────────────────────────
if command -v go >/dev/null 2>&1; then
    printf 'Upgrading Go...\n'
    _pkg_update >/dev/null 2>&1 || true
    case "${FLU_PKG_MGR:-apt}" in
        apt)    _pkg_install golang-go 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
        apk)    _pkg_install go 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
        dnf)    _pkg_install golang 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
        pacman) _pkg_install go 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
        zypper) _pkg_install go 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
        brew)   brew upgrade go 2>/dev/null || printf '  Go upgrade skipped\n' >&2 ;;
    esac
    upgraded=1
    printf '  Go: %s\n' "$(go version 2>/dev/null | head -1)"
fi

# ─── Rust ──────────────────────────
if command -v rustup >/dev/null 2>&1; then
    printf 'Upgrading Rust...\n'
    rustup update 2>/dev/null || { printf '  Rust upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
    printf '  Rust: %s\n' "$(rustc --version 2>/dev/null | head -1)"
fi

# ─── Node.js / NVM ─────────────────
if command -v nvm >/dev/null 2>&1; then
    printf 'Upgrading NVM...\n'
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh -o /tmp/nvm-install.sh 2>/dev/null || true
    elif command -v wget >/dev/null 2>&1; then
        wget -qO /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh 2>/dev/null || true
    fi
    if [ -f /tmp/nvm-install.sh ]; then
        bash /tmp/nvm-install.sh 2>/dev/null || printf '  NVM upgrade failed\n' >&2
        rm -f /tmp/nvm-install.sh
        . "${HOME}/.nvm/nvm.sh" 2>/dev/null || true
    fi

    printf 'Upgrading Node.js to latest LTS...\n'
    nvm install --lts --reinstall-packages-from=current 2>/dev/null || { printf '  Node LTS upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
    printf '  Node.js: %s\n' "$(node --version 2>/dev/null | head -1)"
elif command -v node >/dev/null 2>&1; then
    # Node without NVM — try package manager
    if [ "${FLU_PKG_MGR:-}" = "apk" ]; then
        _maybe_sudo apk upgrade nodejs npm 2>/dev/null || true
        upgraded=1
    fi
fi

# ─── Bun ───────────────────────────
if command -v bun >/dev/null 2>&1; then
    printf 'Upgrading Bun...\n'
    bun upgrade 2>/dev/null || {
        # Fallback: reinstall via installer
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL https://bun.sh/install -o /tmp/bun-install.sh 2>/dev/null || true
        elif command -v wget >/dev/null 2>&1; then
            wget -qO /tmp/bun-install.sh https://bun.sh/install 2>/dev/null || true
        fi
        if [ -f /tmp/bun-install.sh ]; then
            bash /tmp/bun-install.sh 2>/dev/null || printf '  Bun upgrade failed\n' >&2
            rm -f /tmp/bun-install.sh
        fi
    }
    upgraded=1
    printf '  Bun: %s\n' "$(bun --version 2>/dev/null | head -1)"
fi

# ─── Python ────────────────────────
if command -v python3 >/dev/null 2>&1; then
    printf 'Upgrading Python packages...\n'
    # pip
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --upgrade pip 2>/dev/null || true
    fi
    # pipx
    if command -v pipx >/dev/null 2>&1; then
        pipx upgrade-all 2>/dev/null || true
    fi
    # uv
    if command -v uv >/dev/null 2>&1; then
        uv self update 2>/dev/null || true
    fi
    upgraded=1
    printf '  Python: %s\n' "$(python3 --version 2>/dev/null | head -1)"
fi

# ─── PHP ───────────────────────────
if command -v php >/dev/null 2>&1; then
    printf 'Upgrading PHP...\n'
    _pkg_update >/dev/null 2>&1 || true
    case "${FLU_PKG_MGR:-apt}" in
        apk)    _pkg_install php-cli php-xml php-mbstring php-curl php-json composer 2>/dev/null || true ;;
        *)      _pkg_install php-cli php-xml php-mbstring php-curl php-json 2>/dev/null || true ;;
    esac
    upgraded=1
    printf '  PHP: %s\n' "$(php -v 2>/dev/null | head -1)"
fi

# ─── Yarn ──────────────────────────
if command -v npm >/dev/null 2>&1 && command -v yarn >/dev/null 2>&1; then
    printf 'Upgrading Yarn...\n'
    npm update -g yarn 2>/dev/null || { printf '  Yarn upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
    printf '  Yarn: %s\n' "$(yarn --version 2>/dev/null | head -1)"
fi

# ─── Tailscale ─────────────────────
if command -v tailscale >/dev/null 2>&1; then
    printf 'Upgrading Tailscale...\n'
    if [ "${FLU_OS:-linux}" = "darwin" ]; then
        brew upgrade tailscale 2>/dev/null || { printf '  Tailscale upgrade failed\n' >&2; failures=$((failures + 1)); }
    else
        curl -fsSL https://tailscale.com/install.sh | sh 2>/dev/null || { printf '  Tailscale upgrade failed\n' >&2; failures=$((failures + 1)); }
    fi
    upgraded=1
    printf '  Tailscale: %s\n' "$(tailscale version 2>/dev/null | head -1)"
fi

# ─── OpenCode ──────────────────────
if command -v opencode >/dev/null 2>&1 || npm list -g opencode-ai >/dev/null 2>&1; then
    printf 'Upgrading OpenCode...\n'
    npm update -g opencode-ai 2>/dev/null || { printf '  OpenCode upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
    printf '  OpenCode: %s\n' "$(opencode --version 2>/dev/null | head -1 || printf 'updated')"
fi

# ─── GSD ───────────────────────────
if npx --yes gsd-opencode --version 2>/dev/null | grep -q '[0-9]'; then
    printf 'Upgrading GSD (Rokicool)...\n'
    npx gsd-opencode@latest 2>/dev/null || { printf '  GSD (Rokicool) upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
fi

# ─── OpenChamber ───────────────────
if command -v openchamber >/dev/null 2>&1 || npm list -g @openchamber/web >/dev/null 2>&1; then
    printf 'Upgrading OpenChamber...\n'
    npm update -g @openchamber/web 2>/dev/null || { printf '  OpenChamber upgrade failed\n' >&2; failures=$((failures + 1)); }
    upgraded=1
fi

printf '\n'
if [ "$upgraded" -eq 0 ]; then
    printf 'No installed tools found to upgrade.\n'
    printf 'Install tools first from the Languages & Runtimes and Tools menus.\n'
elif [ "$failures" -eq 0 ]; then
    printf 'All tools upgraded successfully.\n'
else
    printf 'Upgrade complete with %d failure(s).\n' "$failures"
    printf 'Individual tools can be reinstalled from their menu entries.\n'
fi
