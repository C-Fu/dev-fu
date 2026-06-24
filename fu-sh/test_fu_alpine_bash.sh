#!/usr/bin/env bash
set -eu

# Contract test for _ensure_alpine_bash() — extracts the real helper from fu.sh
# and exercises it with stubs. Does NOT require a real Alpine environment.

# Resolve repo root (test may be run from repo root or from fu-sh/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FU="${1:-${REPO_ROOT}/fu-sh/fu.sh}"

if [ ! -f "$FU" ]; then
    echo "FAIL: fu.sh not found at $FU" >&2
    exit 1
fi

# Extract the real helper from fu.sh
HELPER="$(sed -n '/^_ensure_alpine_bash()[[:space:]]*{/,/^}/p' "$FU")"
if [ -z "$HELPER" ]; then
    echo "FAIL: _ensure_alpine_bash() not found in $FU" >&2
    exit 1
fi

# Color stubs
CYAN="" RED="" NC=""

# pkg_install stub — writes args to marker file
pkg_install() {
    echo "$@" >> /tmp/.alpine_bash_test_marker
}

# command() stub — shadows builtin for controlling bash/apk availability
# HAVE_BASH=1 → command -v bash succeeds; HAVE_APK=1 → command -v apk succeeds
command() {
    local cmd="$1"
    case "$cmd" in
        -v)
            local target="$2"
            case "$target" in
                bash) [ "${HAVE_BASH:-0}" = "1" ] && return 0 || return 1 ;;
                apk)  [ "${HAVE_APK:-0}" = "1" ] && return 0 || return 1 ;;
                *)    return 1 ;;
            esac
            ;;
        *)  return 1 ;;
    esac
}

# Load the real helper
eval "$HELPER"

MARKER="/tmp/.alpine_bash_test_marker"
pass=0
fail=0

run_case() {
    local name="$1" have_bash="$2" have_apk="$3" expect_marker="$4"
    rm -f "$MARKER"
    HAVE_BASH="$have_bash"
    HAVE_APK="$have_apk"
    local rc=0
    _ensure_alpine_bash || rc=$?
    local marker_content=""
    [ -f "$MARKER" ] && marker_content="$(cat "$MARKER")"

    if [ "$expect_marker" = "empty" ] && [ -z "$marker_content" ]; then
        echo "ok: $name"
        pass=$((pass + 1))
    elif [ "$expect_marker" = "bash" ] && echo "$marker_content" | grep -q "bash"; then
        echo "ok: $name"
        pass=$((pass + 1))
    else
        echo "FAIL: $name (marker='$marker_content' expected='$expect_marker' rc=$rc)"
        fail=$((fail + 1))
    fi
}

# Case A: bash present → no-op, no pkg_install call
run_case "bash-present-noop" 1 1 "empty"

# Case B: bash absent + apk present (Alpine) → triggers pkg_install bash
run_case "alpine-bash-absent-installs" 0 1 "bash"

# Case C: bash absent + apk absent (non-Alpine) → graceful no-op
run_case "non-alpine-bash-absent-noop" 0 0 "empty"

rm -f "$MARKER"
echo "pass=$pass fail=$fail"
[ "$fail" = "0" ]
