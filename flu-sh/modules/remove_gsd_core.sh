#!/usr/bin/env sh
# @name: Remove gsd-core (Open GSD)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 60
#
# Removes the gsd-core project artifacts (Open GSD).
# gsd-core is invoked via `npx @opengsd/gsd-core@latest` per-project and
# does not install globally. This removes the `.planning/` directory
# and any GSD Core hooks/slash-commands left behind in the current
# project. Run from the project root you want to clean.

set -eu

# gsd-core is npx-based, no global install to remove
printf 'gsd-core is invoked per-project via npx — no global install to remove.\n'

if [ -d .planning ]; then
    printf 'Removing .planning/ directory in current project...\n'
    rm -rf .planning
    printf '.planning/ removed successfully\n'
else
    printf 'No .planning/ directory found in current directory.\n'
fi

printf 'If GSD Core added commands/agents to your AI runtime, run:\n'
printf '  npx @opengsd/gsd-core@latest --uninstall\n'
printf 'gsd-core removal complete\n'
