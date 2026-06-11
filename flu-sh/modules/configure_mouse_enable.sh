#!/usr/bin/env sh
# @name: Mouse Reporting (Enable)
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps:
# @timeout: 30
#
# Enables terminal mouse reporting by sending the XTerm-compatible
# escape sequence to enable mouse tracking.
# This affects the current terminal session only.

set -eu

# Send escape sequence to enable mouse tracking (XTerm-compatible)
printf '\033[?1000h'

printf 'Mouse reporting ENABLED for this terminal session.\n'
printf 'Mouse events (click, scroll) will now be reported to the terminal.\n'
printf 'To disable, run "Mouse Reporting (Disable)" from the Settings menu.\n'
