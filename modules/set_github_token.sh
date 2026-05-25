#!/usr/bin/env sh
# @name: Set GitHub Token
# @params: token=text:Enter your GitHub personal access token
# @platforms: linux, darwin
# @version: 1.0.0
# @deps: curl
# @timeout: 120
#
# Stores a GitHub personal access token for API usage.
# The token is saved to ~/.config/dev-fu/github-token with
# restricted permissions (chmod 600).
# Accepts --token via command line or prompts for input.

set -eu

TOKEN_FILE="${HOME}/.config/dev-fu/github-token"
GH_TOKEN=""

# MODL-08 parameter parsing: accept --token from flu_module_collect_params
while [ $# -gt 0 ]; do
    case "$1" in
        --token)
            if [ -n "${2:-}" ]; then
                GH_TOKEN="$2"
                shift 2
            else
                shift
            fi
            ;;
        *)
            shift
            ;;
    esac
done

# If no --token provided, prompt interactively
if [ -z "$GH_TOKEN" ]; then
    printf 'Enter GitHub personal access token: '
    IFS= read -r GH_TOKEN
fi

# Validate input
if [ -z "$GH_TOKEN" ]; then
    printf 'No token provided — cancelled.\n'
    exit 0
fi

# Check for existing token
if [ -f "$TOKEN_FILE" ]; then
    cur=$(cat "$TOKEN_FILE" 2>/dev/null || true)
    if [ -n "$cur" ] && [ "$cur" = "$GH_TOKEN" ]; then
        printf 'GitHub token already set at %s\n' "$TOKEN_FILE"
        printf 'Token: %s****%s\n' "$(printf '%.4s' "$GH_TOKEN")" "$(printf '%.4s' "$GH_TOKEN" | tail -c 5 2>/dev/null || printf '')"
        exit 0
    fi
fi

# Save the token
mkdir -p "$(dirname "$TOKEN_FILE")"
printf '%s' "$GH_TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

printf 'GitHub token saved to %s\n' "$TOKEN_FILE"

# Verify the token works
printf 'Verifying token...\n'
test_result=$(curl -sL --connect-timeout 10 --max-time 15 \
    -H "Authorization: token ${GH_TOKEN}" \
    "https://api.github.com/rate_limit" 2>/dev/null | \
    grep '"remaining"' | head -1 | grep -oE '[0-9]+' 2>/dev/null || true)

if [ -n "$test_result" ]; then
    printf 'Token verified — API rate limit: %s requests remaining\n' "$test_result"
else
    printf 'Warning: token saved but verification failed — check if the token is valid\n' >&2
fi
