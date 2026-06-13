#!/bin/sh
# run.sh — curl-pipe-run fust (no install, just run)
# Usage: curl -fsSL https://flu.sh/run | sh
#        curl -fsSL https://flu.sh/run | FLU_VERSION=v3.0.0-alpha.2 sh

set -eu

REPO="${FLU_REPO:-C-Fu/dev-fu}"
VERSION="${FLU_VERSION:-}"
BINARY_NAME="fust"

# ── Cleanup on exit ──────────────────────────────────────────────
TMPDIR=""
cleanup() {
    if [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

# ── Detect platform ──────────────────────────────────────────────
detect_target() {
    os="$(uname -s 2>/dev/null || true)"
    arch="$(uname -m 2>/dev/null || true)"

    case "$os" in
        Linux)      vendor="unknown"; system="linux-musl";  ext="tar.gz" ;;
        Darwin)     vendor="apple";   system="darwin";      ext="tar.gz" ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            vendor="pc"; system="windows-msvc"; ext="zip" ;;
        *)          echo "Error: unsupported OS '$os'" >&2; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) printf "x86_64-%s-%s.%s" "$vendor" "$system" "$ext" ;;
        aarch64|arm64) printf "aarch64-%s-%s.%s" "$vendor" "$system" "$ext" ;;
        armv7l|armv7|armhf) printf "armv7-unknown-linux-musleabihf.%s" "$ext" ;;
        *)  echo "Error: unsupported arch '$arch'" >&2; exit 1 ;;
    esac
}

# ── Get latest release tag ───────────────────────────────────────
latest_tag() {
    tag="$(curl -sSL -H "Accept: application/vnd.github+json" \
            "https://api.github.com/repos/${REPO}/releases" 2>/dev/null \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -1)" || true

    if [ -n "$tag" ]; then
        printf "%s" "$tag"
        return
    fi

    tag="$(curl -sSL "https://github.com/${REPO}/releases" 2>/dev/null \
        | sed -n 's|.*/releases/tag/\([^"]*\)".*|\1|p' \
        | head -1)" || true

    if [ -n "$tag" ]; then
        printf "%s" "$tag"
        return
    fi

    echo "Error: could not find latest version. Set FLU_VERSION." >&2
    exit 1
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    target_info="$(detect_target)"
    case "$target_info" in
        *.tar.gz) target="${target_info%.tar.gz}"; ext="tar.gz" ;;
        *.zip)    target="${target_info%.zip}";    ext="zip" ;;
        *)        echo "Error: unknown archive format" >&2; exit 1 ;;
    esac

    if [ -n "$VERSION" ]; then
        tag="${VERSION}"; case "$tag" in v*) ;; *) tag="v${tag}" ;; esac
    else
        tag="$(latest_tag)"
    fi

    url="https://github.com/${REPO}/releases/download/${tag}/fust-${target}.${ext}"
    echo "Fetching fust ${tag} for ${target} ..."

    TMPDIR="$(mktemp -d)"
    archive="${TMPDIR}/fust.${ext}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$archive" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$archive" "$url"
    else
        echo "Error: curl or wget required" >&2; exit 1
    fi

    case "$ext" in
        tar.gz) tar -xzf "$archive" -C "$TMPDIR" ;;
        zip)    unzip -qo "$archive" -d "$TMPDIR" ;;
    esac || { echo "Error: extraction failed" >&2; exit 1; }

    bin="${TMPDIR}/${BINARY_NAME}"
    [ -f "${bin}.exe" ] && bin="${bin}.exe"
    if [ ! -f "$bin" ]; then
        echo "Error: binary not found in archive" >&2; exit 1
    fi
    chmod +x "$bin"

    echo "Running fust ..."
    echo ""
    if [ -t 0 ]; then
        exec "$bin" "$@"
    elif [ -e /dev/tty ]; then
        exec "$bin" "$@" < /dev/tty
    else
        exec "$bin" "$@"
    fi
}

main "$@"
