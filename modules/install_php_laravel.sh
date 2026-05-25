#!/usr/bin/env sh
# @name: Install PHP + Laravel
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 600
#
# Installs PHP 8.x, Composer, and the Laravel installer.
# PHP and Composer via package manager, Laravel via Composer global.

set -eu

_maybe_sudo() {
    if [ "${FLU_IS_ROOT:-0}" = "1" ] || ! command -v sudo >/dev/null 2>&1; then
        "$@"
    else
        sudo -n "$@" 2>/dev/null || { printf 'sudo password required\n' >&2; return 1; }
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

if command -v php >/dev/null 2>&1 && command -v composer >/dev/null 2>&1 && command -v laravel >/dev/null 2>&1; then
    printf 'PHP + Composer + Laravel already installed\n'
    printf '  PHP: %s\n' "$(php -v 2>/dev/null | head -n1)"
    exit 0
fi

_pkg_update || { printf 'Package update failed\n' >&2; exit 1; }

# Install PHP and Composer based on package manager
if ! command -v php >/dev/null 2>&1 || ! command -v composer >/dev/null 2>&1; then
    printf 'Installing PHP + Composer...\n'
    case "${FLU_PKG_MGR:-apt}" in
        apt)
            _pkg_install php-cli php-xml php-mbstring php-curl php-common composer || { printf 'PHP install failed\n' >&2; exit 1; }
            ;;
        apk)
            _pkg_install php81 php81-mbstring php81-xml php81-curl php81-openssl composer || { printf 'PHP install failed\n' >&2; exit 1; }
            ;;
        dnf)
            _pkg_install php-cli php-xml php-mbstring php-curl php-json || { printf 'PHP install failed\n' >&2; exit 1; }
            if ! command -v composer >/dev/null 2>&1; then
                printf 'Installing Composer...\n'
                if command -v curl >/dev/null 2>&1; then
                    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 2>/dev/null || true
                fi
            fi
            ;;
        pacman)
            _pkg_install php composer || { printf 'PHP install failed\n' >&2; exit 1; }
            ;;
        zypper)
            _pkg_install php8 php8-mbstring php8-xml php8-curl php8-openssl || { printf 'PHP install failed\n' >&2; exit 1; }
            ;;
        brew)
            brew install php composer || { printf 'PHP install failed\n' >&2; exit 1; }
            ;;
        *)
            printf 'Unsupported package manager: %s\n' "${FLU_PKG_MGR:-unknown}" >&2
            exit 1
            ;;
    esac
fi

# Install Laravel installer via Composer
if command -v composer >/dev/null 2>&1; then
    if command -v laravel >/dev/null 2>&1; then
        printf 'Laravel installer already present\n'
    else
        printf 'Installing Laravel installer...\n'
        composer global require laravel/installer || { printf 'Laravel installer install failed\n' >&2; exit 1; }
        # Add Composer vendor bin to PATH for current session
        export PATH="$HOME/.composer/vendor/bin:$PATH"
    fi
else
    printf 'Composer not found — skipping Laravel installer\n' >&2
fi

printf 'PHP + Laravel installed successfully\n'
