#!/usr/bin/env sh
# @name: Install Hermes Agent
# @params:
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl
# @timeout: 300
#
# Installs Hermes Agent from NousResearch.
# https://github.com/NousResearch/hermes-agent
# Uses the official install script via curl.

set -eu

printf 'Installing Hermes Agent...\n'
if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | sh
elif command -v wget >/dev/null 2>&1; then
    wget -qO- https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | sh
else
    printf 'curl or wget is required.\n' >&2
    exit 1
fi

printf 'Hermes Agent installed successfully\n'
