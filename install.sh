#!/bin/sh
# install.sh — curl-pipe-bash installer for fust
# Usage: curl -fsSL https://flu.sh | sh
#        curl -fsSL https://flu.sh | FLU_VERSION=v0.1.0 sh
#        curl -fsSL https://flu.sh | INSTALL_DIR=/usr/local/bin sh

set -eu

REPO="${FLU_REPO:-C-Fu/dev-fu}"
VERSION="${FLU_VERSION:-}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
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
detect_platform() {
    os="$(uname -s 2>/dev/null || true)"
    arch="$(uname -m 2>/dev/null || true)"

    case "$os" in
        Linux)  vendor="unknown";   system="linux-musl" ;;
        Darwin) vendor="apple";     system="darwin" ;;
        *)      echo "Error: unsupported OS '$os'" >&2; exit 1 ;;
    esac

    case "$arch" in
        x86_64|amd64) target_triple="x86_64-${vendor}-${system}" ;;
        aarch64|arm64) target_triple="aarch64-${vendor}-${system}" ;;
        armv7l|armv7|armhf) target_triple="armv7-${vendor}-linux-musleabihf" ;;
        *)      echo "Error: unsupported architecture '$arch'" >&2; exit 1 ;;
    esac

    printf "%s" "$target_triple"
}

# ── Resolve download URL ─────────────────────────────────────────
resolve_url() {
    target="$1"

    if [ -n "$VERSION" ]; then
        # Specific version requested
        tag="${VERSION#v}"
        printf "https://github.com/%s/releases/download/v%s/fust-%s.tar.gz" \
            "$REPO" "$tag" "$target"
        return
    fi

    # Fetch latest release from GitHub API
    api_url="https://api.github.com/repos/${REPO}/releases/latest"
    release_json="$(fetch_url "$api_url")" || {
        echo "Error: failed to fetch latest release info" >&2
        exit 1
    }

    # Extract tag name and asset URL for matching target
    tag_name="$(printf "%s" "$release_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
    if [ -z "$tag_name" ]; then
        echo "Error: could not determine latest version" >&2
        exit 1
    fi

    asset_pattern="fust-${target}.tar.gz"
    asset_url="$(printf "%s" "$release_json" | sed -n "s|.*\"browser_download_url\"[[:space:]]*:[[:space:]]*\"\\([^\"]*${asset_pattern}\\)\".*|\\1|p" | head -1)"

    if [ -z "$asset_url" ]; then
        echo "Error: no release asset found for target '$target'" >&2
        exit 1
    fi

    printf "%s" "$asset_url"
}

# ── Download helper (curl or wget) ───────────────────────────────
fetch_url() {
    url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$url"
    else
        echo "Error: curl or wget required" >&2
        exit 1
    fi
}

# ── Main ─────────────────────────────────────────────────────────
main() {
    target="$(detect_platform)"
    echo "Detected platform: $target"

    download_url="$(resolve_url "$target")"
    echo "Downloading: $download_url"

    TMPDIR="$(mktemp -d)"
    tarball="${TMPDIR}/fust-${target}.tar.gz"

    # Download tarball
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$tarball" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tarball" "$download_url"
    else
        echo "Error: curl or wget required" >&2
        exit 1
    fi

    # Extract
    tar -xzf "$tarball" -C "$TMPDIR" || {
        echo "Error: extraction failed" >&2
        exit 1
    }

    if [ ! -f "${TMPDIR}/${BINARY_NAME}" ]; then
        echo "Error: binary '${BINARY_NAME}' not found in archive" >&2
        exit 1
    fi

    # Install
    mkdir -p "$INSTALL_DIR"
    mv "${TMPDIR}/${BINARY_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    installed_path="${INSTALL_DIR}/${BINARY_NAME}"
    echo ""
    echo "✓ fust installed to ${installed_path}"

    # PATH warning
    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            echo ""
            echo "⚠ ${INSTALL_DIR} is not in your PATH."
            echo "  Add it with: export PATH=\"${INSTALL_DIR}:\$PATH\""
            ;;
    esac
}

main "$@"
