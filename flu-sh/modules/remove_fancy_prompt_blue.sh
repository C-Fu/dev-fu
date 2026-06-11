#!/usr/bin/env sh
# @name: Remove Fancy Prompt (Shades of Blue)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Removes the Shades-of-Blue fancy prompt block from ~/.bashrc
# by deleting all lines between the dev-fu blue marker comments.

set -eu

RC_FILE="${HOME}/.bashrc"
MARKER_START="# dev-fu blue prompt start"
MARKER_END="# dev-fu blue prompt end"

# Idempotent guard: if not installed, exit cleanly
if [ ! -f "$RC_FILE" ] || ! grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
    printf 'Fancy Prompt (Shades of Blue) is not installed\n'
    exit 0
fi

printf 'Removing Fancy Prompt (Shades of Blue)...\n'

# Remove all lines between (and including) the marker comments
TMP_FILE="${RC_FILE}.tmp.$$"
sed "/${MARKER_START}/,/${MARKER_END}/d" "$RC_FILE" > "$TMP_FILE" 2>/dev/null

# Only replace if sed worked and temp file is non-empty
if [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$RC_FILE"
else
    rm -f "$TMP_FILE"
    printf 'Warning: could not modify %s\n' "$RC_FILE" >&2
    exit 1
fi

printf 'Fancy Prompt (Shades of Blue) removed from %s\n' "$RC_FILE"
printf 'Run: source %s   (or open a new terminal)\n' "$RC_FILE"
printf '\n'
