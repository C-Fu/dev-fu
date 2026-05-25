#!/usr/bin/env sh
# @name: Mouse Reporting (Disable)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 30
#
# Disables terminal mouse reporting by sending the XTerm-compatible
# escape sequence to disable mouse tracking.
# This affects the current terminal session only.

set -eu

# Send escape sequence to disable mouse tracking (XTerm-compatible)
printf '\033[?1000l'

printf 'Mouse reporting DISABLED for this terminal session.\n'
printf 'Normal terminal selection behavior restored.\n'
printf 'To re-enable, run "Mouse Reporting (Enable)" from the Settings menu.\n'
