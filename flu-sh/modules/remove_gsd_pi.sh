#!/usr/bin/env sh
# @name: Remove gsd-pi (Open GSD)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Removes the gsd-pi project artifacts (Open GSD).
# gsd-pi is invoked via `npx @opengsd/gsd-pi@latest` per-project and does
# not install globally. This removes the `.gsd/` directory (SQLite
# database + markdown projections) from the current project.
# Run from the project root you want to clean.

set -eu

# gsd-pi is npx-based, no global install to remove
printf 'gsd-pi is invoked per-project via npx — no global install to remove.\n'

if [ -d .gsd ]; then
    printf 'Removing .gsd/ directory in current project...\n'
    rm -rf .gsd
    printf '.gsd/ removed successfully\n'
else
    printf 'No .gsd/ directory found in current directory.\n'
fi

printf 'If GSD Pi created worktrees, remove them with:\n'
printf '  git worktree remove <path> && git worktree prune\n'
printf 'gsd-pi removal complete\n'
