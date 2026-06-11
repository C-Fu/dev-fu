#!/usr/bin/env sh
# @name: Remove Fancy Prompt (Purple-Pink)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Removes the Purple-Pink fancy prompt block from ~/.bashrc
# by deleting all lines between the dev-fu marker comments.

set -eu

RC_FILE="${HOME}/.bashrc"
MARKER_START="# dev-fu purple-pink prompt start"
MARKER_END="# dev-fu purple-pink prompt end"

# Idempotent guard: if not installed, exit cleanly
if [ ! -f "$RC_FILE" ] || ! grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
    printf 'Fancy Prompt (Purple-Pink) is not installed\n'
    exit 0
fi

printf 'Removing Fancy Prompt (Purple-Pink)...\n'

# Remove all lines between (and including) the marker comments
# Use sed to delete the range, writing to a temp file then moving back
TMP_FILE="${RC_FILE}.tmp.$$"
sed "/${MARKER_START}/,/${MARKER_END}/d" "$RC_FILE" > "$TMP_FILE" 2>/dev/null

# Only replace if sed worked and temp file is non-empty
if [ -s "$TMP_FILE" ]; then
    mv "$TMP_FILE" "$RC_FILE"
else
    # If something went wrong, restore from backup or warn
    rm -f "$TMP_FILE"
    printf 'Warning: could not modify %s — file might be corrupted\n' "$RC_FILE" >&2
    exit 1
fi

# Remove any trailing blank lines left from the deletion
# (sed on BSD/macOS handles -i differently, so use temp file approach)

printf 'Fancy Prompt (Purple-Pink) removed from %s\n' "$RC_FILE"
printf 'Run: source %s   (or open a new terminal)\n' "$RC_FILE"
printf '\n'
