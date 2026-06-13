#!/usr/bin/env sh
# @name: Fancy Prompt (Shades of Blue)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Installs a Shades-of-Blue fancy prompt by writing a PS1 definition
# into ~/.bashrc between marker comments.
# The prompt content uses bash syntax (PS1 escapes) which is fine
# because .bashrc is sourced by bash; this module script is POSIX sh.

set -eu

RC_FILE="${HOME}/.bashrc"
MARKER_START="# dev-fu blue prompt start"
MARKER_END="# dev-fu blue prompt end"

# Idempotent guard
if [ -f "$RC_FILE" ] && grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
    printf 'Fancy Prompt (Shades of Blue) is already installed in %s\n' "$RC_FILE"
    exit 0
fi

printf 'Installing Fancy Prompt (Shades of Blue)...\n'

# Append the prompt definition to ~/.bashrc
cat >> "$RC_FILE" << 'PROMPT_BLOCK'
# dev-fu blue prompt start
# Fancy Prompt (Shades of Blue) — installed by flu.sh

_fp_blue_prompt() {
    # Shades of Blue color scheme using 256-colour terminal
    local CLR_RESET="\[\033[0m\]"
    local CLR_DARK_BG="\[\033[48;5;17m\]"
    local CLR_DARK_FG="\[\033[38;5;255m\]"
    local CLR_MED_BG="\[\033[48;5;25m\]"
    local CLR_MED_FG="\[\033[38;5;255m\]"
    local CLR_LIGHT_BG="\[\033[48;5;74m\]"
    local CLR_LIGHT_FG="\[\033[38;5;255m\]"
    local CLR_SEP1="\[\033[38;5;17;48;5;25m\]"
    local CLR_SEP2="\[\033[38;5;25;48;5;74m\]"
    local CLR_SEP3="\[\033[38;5;74m\]"

    local SEP="\uE0B0"
    local PROMPT="${CLR_DARK_BG}${CLR_DARK_FG} \u ${CLR_SEP1}${SEP}${CLR_MED_BG}${CLR_MED_FG} \h ${CLR_SEP2}${SEP}${CLR_LIGHT_BG}${CLR_LIGHT_FG} \w ${CLR_SEP3}${SEP}${CLR_RESET} "

    PS1="$PROMPT"
}

PROMPT_COMMAND=_fp_blue_prompt
# dev-fu blue prompt end
PROMPT_BLOCK

printf 'Fancy Prompt (Shades of Blue) installed in %s\n' "$RC_FILE"
printf 'Run: source %s   (or open a new terminal)\n' "$RC_FILE"
printf '\n'
