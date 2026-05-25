#!/usr/bin/env sh
# @name: Compare With Latest
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl,wget
# @timeout: 300
#
# Compares installed tool versions against the latest available
# versions by querying online registries (GitHub API, npm, PyPI, etc.).
# Falls back gracefully on network errors or rate limiting.

set -eu

# Source NVM if available
if [ -s "${HOME}/.nvm/nvm.sh" ]; then
    . "${HOME}/.nvm/nvm.sh" 2>/dev/null || true
fi

# Add common local paths
export PATH="${HOME}/.local/bin:${HOME}/.npm/bin:${PATH}"

# GitHub token for authenticated API requests
_GH_AUTH_HEADER=""
_GH_TOKEN_FILE="${HOME}/.config/dev-fu/github-token"
if [ -f "$_GH_TOKEN_FILE" ]; then
    _tok=$(cat "$_GH_TOKEN_FILE" 2>/dev/null || true)
    if [ -n "$_tok" ]; then
        _GH_AUTH_HEADER="Authorization: token ${_tok}"
    fi
fi

# Fetch latest version from GitHub releases
_gh_latest() {
    _repo="$1"
    _fallback="$2"
    _tag=""
    _url="https://api.github.com/repos/${_repo}/releases/latest"

    if [ -n "$_GH_AUTH_HEADER" ]; then
        _tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
            -H "$_GH_AUTH_HEADER" "$_url" 2>/dev/null | \
            grep '"tag_name"' | head -1 | \
            sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    else
        _tag=$(curl -fsSL --connect-timeout 5 --max-time 10 \
            "$_url" 2>/dev/null | \
            grep '"tag_name"' | head -1 | \
            sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    if [ -z "$_tag" ] && [ -n "$_fallback" ]; then
        _tag=$(eval "$_fallback" 2>/dev/null || true)
    fi

    # Strip leading 'v', 'docker-v', 'bun-v', 'php-'
    _tag="${_tag#v}"
    _tag="${_tag#docker-v}"
    _tag="${_tag#bun-v}"
    _tag="${_tag#php-}"

    if [ -z "$_tag" ]; then
        printf 'N/A'
    else
        printf '%s' "$_tag"
    fi
}

# Get local version
_local_ver() {
    _cmd="$1"
    _flag="$2"
    if command -v "$_cmd" >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            echo "y" | timeout 5 "$_cmd" $_flag 2>/dev/null | head -1
        else
            echo "y" | "$_cmd" $_flag 2>/dev/null | head -1
        fi
    fi
}

# Extract version number from version string
_extract_ver() {
    printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Compare and format one row
_compare_row() {
    _name="$1"
    _local_raw="$2"
    _latest="$3"

    _local_ver=$(_extract_ver "$_local_raw")
    _lat="${_latest}"

    if [ -z "$_local_raw" ]; then
        printf '  %s | %s | %s | %s\n' "$_name" "not installed" "${_lat:-N/A}" "—" | awk -F'|' '{printf "  %-14s %-24s %-18s %s\n", $1, $2, $3, $4}'
    elif [ -z "$_latest" ] || [ "$_latest" = "N/A" ]; then
        printf '  %s | %s | %s | %s\n' "$_name" "${_local_ver:-?}" "N/A" "?" | awk -F'|' '{printf "  %-14s %-24s %-18s %s\n", $1, $2, $3, $4}'
    elif [ "$_local_ver" = "$_latest" ]; then
        printf '  %s | %s | %s | %s\n' "$_name" "$_local_ver" "$_lat" "up to date" | awk -F'|' '{printf "  %-14s %-24s %-18s %s\n", $1, $2, $3, $4}'
    else
        printf '  %s | %s | %s | %s\n' "$_name" "$_local_ver" "$_lat" "update available" | awk -F'|' '{printf "  %-14s %-24s %-18s %s\n", $1, $2, $3, $4}'
    fi
}

printf 'Compare With Latest — Installed vs Online\n'
printf '==========================================\n'
printf '\n'
printf '  %s | %s | %s | %s\n' "Tool" "Installed" "Latest" "Status" | awk -F'|' '{printf "  %-14s %-24s %-18s %s\n", $1, $2, $3, $4}'
printf '  ------------------------------------------------------------------------\n'

# Go
_compare_row "Go" \
    "$(_local_ver go version)" \
    "$(_gh_latest "golang/go" "curl -fsSL --max-time 5 'https://go.dev/dl/?mode=json' 2>/dev/null | grep '\"version\"' | head -1 | sed 's/.*\"version\"[[:space:]]*:[[:space:]]*\"go\\([^\"]*\\)\".*/\\1/'")"

# Rust
_compare_row "Rust" \
    "$(_local_ver rustc --version)" \
    "$(_gh_latest "rust-lang/rust" "curl -fsSL --max-time 5 'https://static.rust-lang.org/dist/channel-rust-stable.toml' 2>/dev/null | grep '^version =' | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")"

# Bun
_compare_row "Bun" \
    "$(_local_ver bun --version)" \
    "$(_gh_latest "oven-sh/bun" "")"

# Node.js
_compare_row "Node.js" \
    "$(_local_ver node --version)" \
    "$(curl -fsSL --max-time 5 'https://nodejs.org/dist/index.json' 2>/dev/null | grep '\"version\"' | head -1 | sed 's/.*\"version\"[[:space:]]*:[[:space:]]*\"v\\([^\"]*\\)\".*/\\1/')"

# Python
_compare_row "Python" \
    "$(_local_ver python3 --version)" \
    "$(curl -fsSL --max-time 5 'https://endoflife.date/api/python.json' 2>/dev/null | grep -o '\"latest\":\"[^\"]*\"' | head -1 | sed 's/\"latest\":\"//;s/\"//')"

# Docker
_compare_row "Docker" \
    "$(_local_ver docker --version)" \
    "$(_gh_latest "moby/moby" "curl -fsSL --max-time 5 'https://raw.githubusercontent.com/moby/moby/refs/heads/master/VERSION' 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")"

# Tailscale
_compare_row "Tailscale" \
    "$(_local_ver tailscale version)" \
    "$(_gh_latest "tailscale/tailscale" "")"

# OpenCode
_compare_row "OpenCode" \
    "$(_local_ver opencode --version)" \
    "$(_gh_latest "anomalyco/opencode" "curl -fsSL --max-time 5 'https://registry.npmjs.org/opencode-ai/latest' 2>/dev/null | grep -oE '\"version\":\"[0-9]+\\.[0-9]+\\.[0-9]+\"' | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")"

# GSD
_gsd_local=""
_gsd_local=$(npm list -g gsd-opencode 2>/dev/null | grep -oE 'gsd-opencode@[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [ -z "$_gsd_local" ]; then
    _gsd_local=$(_extract_ver "$(npx --yes gsd-opencode --version 2>/dev/null | head -1)")
fi
_compare_row "GSD" \
    "$_gsd_local" \
    "$(_gh_latest "rokicool/gsd-opencode" "")"

# PHP
_compare_row "PHP" \
    "$(_local_ver php -v)" \
    "$(_gh_latest "php/php-src" "")"

# Composer
_compare_row "Composer" \
    "$(_local_ver composer --version)" \
    "$(_gh_latest "composer/composer" "curl -fsSL --max-time 5 'https://getcomposer.org/download/' 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1")"

# NVM
_nvm_local=""
if [ -s "${HOME}/.nvm/nvm.sh" ]; then
    _nvm_local=$(. "${HOME}/.nvm/nvm.sh" 2>/dev/null && nvm --version 2>/dev/null || true)
fi
_compare_row "NVM" \
    "$_nvm_local" \
    "$(_gh_latest "nvm-sh/nvm" "curl -fsSL --max-time 5 'https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/package.json' 2>/dev/null | grep '\"version\"' | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")"

# uv
_compare_row "uv" \
    "$(_local_ver uv --version)" \
    "$(_gh_latest "astral-sh/uv" "curl -fsSL --max-time 5 'https://pypi.org/pypi/uv/json' 2>/dev/null | grep -oE '\"version\":\"[0-9]+\\.[0-9]+\\.[0-9]+\"' | head -1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+'")"

# Yarn
_yarn_latest=""
if command -v npm >/dev/null 2>&1; then
    _yarn_latest=$(npm view yarn version 2>/dev/null || true)
fi
_compare_row "Yarn" \
    "$(_local_ver yarn --version)" \
    "$_yarn_latest"

# OpenChamber
_oc_local=""
_oc_local=$(_local_ver openchamber --version)
if [ -z "$_oc_local" ] && npm list -g @openchamber/web >/dev/null 2>&1; then
    _oc_local="npm global"
fi
_oc_latest=""
if command -v npm >/dev/null 2>&1; then
    _oc_latest=$(npm view @openchamber/web version 2>/dev/null || true)
fi
_compare_row "OpenChamber" \
    "$_oc_local" \
    "$_oc_latest"

printf '  %s\n' "$(printf '%.0s-' $(seq 1 72))"
printf '\n'
printf 'Comparison complete.\n'
