#!/usr/bin/env sh
# @name: Fancy Prompt (Purple-Pink)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Installs a Purple-Pink starburst-style fancy prompt by writing
# a PS1 definition into ~/.bashrc between marker comments.
# The prompt content uses bash syntax (PS1 escapes) which is fine
# because .bashrc is sourced by bash; this module script is POSIX sh.

set -eu

RC_FILE="${HOME}/.bashrc"
MARKER_START="# dev-fu purple-pink prompt start"
MARKER_END="# dev-fu purple-pink prompt end"

# Idempotent guard
if [ -f "$RC_FILE" ] && grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
    printf 'Fancy Prompt (Purple-Pink) is already installed in %s\n' "$RC_FILE"
    exit 0
fi

printf 'Installing Fancy Prompt (Purple-Pink)...\n'

# Append the prompt definition to ~/.bashrc
cat >> "$RC_FILE" << 'PROMPT_BLOCK'
# dev-fu purple-pink prompt start
# Fancy Prompt (Purple-Pink) — installed by flu.sh

_fp_purple_prompt() {
    local EXIT_CODE=$?
    # Purple-Pink color scheme using 256-colour terminal
    local CLR_RESET="\[\033[0m\]"
    local CLR_USER_BG="\[\033[48;5;99m\]"     # mauve background
    local CLR_USER_FG="\[\033[38;5;255m\]"     # white foreground
    local CLR_PATH_BG="\[\033[48;5;69m\]"      # violet background
    local CLR_PATH_FG="\[\033[38;5;255m\]"     # white foreground
    local CLR_PINK_BG="\[\033[48;5;169m\]"     # pink background
    local CLR_PINK_FG="\[\033[38;5;255m\]"     # white foreground
    local CLR_PINK_SEP="\[\033[38;5;99;48;5;169m\]"  # mauve on pink (separator)
    local CLR_SEP_PATH="\[\033[38;5;169;48;5;69m\]"  # pink on violet
    local CLR_RESET_SEP="\[\033[38;5;69m\]"     # violet on default

    # Build the prompt with powerline-style separators (using triangle char)
    local SEP="\uE0B0"
    local PROMPT="${CLR_USER_BG}${CLR_USER_FG} \u@\h ${CLR_PINK_SEP}${SEP}${CLR_PINK_BG}${CLR_PINK_FG} \w ${CLR_SEP_PATH}${SEP}${CLR_RESET_SEP}${SEP}${CLR_RESET} "

    PS1="$PROMPT"
}

PROMPT_COMMAND=_fp_purple_prompt
# dev-fu purple-pink prompt end
PROMPT_BLOCK

printf 'Fancy Prompt (Purple-Pink) installed in %s\n' "$RC_FILE"
printf 'Run: source %s   (or open a new terminal)\n' "$RC_FILE"
printf '\n'
