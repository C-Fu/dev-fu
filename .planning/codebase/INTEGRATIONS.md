# External Integrations

**Analysis Date:** 2026-05-22

## APIs & External Services

**GitHub REST API:**
- Purpose: Fetch latest release versions for all managed tools.
- Endpoint: `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- Endpoint: `https://api.github.com/repos/{owner}/{repo}/tags?per_page=1`
- Auth: Optional — GitHub Personal Access Token stored at `~/.config/dev-fu/github-token`. Increases rate limit from 60 to 5,000 req/hr.
- Client: `curl` via `_scc_gh()` function in `fu.sh` (line ~1327) and `Get-GhLatestTag` in `fu.ps1`.
- Repositories queried: `moby/moby`, `rust-lang/rust`, `oven-sh/bun`, `nvm-sh/nvm`, `astral-sh/uv`, `anomalyco/opencode`, `rokicool/gsd-opencode`, `php/php-src`, `composer/composer`, `tailscale/tailscale`.
- Direction: Outbound (read-only).

**GitHub Rate Limit API:**
- Purpose: Verify GitHub token validity.
- Endpoint: `https://api.github.com/rate_limit`
- Auth: Bearer token via `Authorization: token {token}` header.
- Direction: Outbound (read-only).

**npm Registry:**
- Purpose: Fetch latest versions for Node.js packages.
- Endpoint: `https://registry.npmjs.org/opencode-ai/latest`
- Endpoint: `https://registry.npmjs.org/gsd-opencode/latest`
- Client: `curl` in `fu.sh`, `Invoke-RestMethod` in `fu.ps1`.
- Auth: None (public registry).
- Direction: Outbound (read-only).

**Go Download API:**
- Purpose: Fetch latest Go version.
- Endpoint: `https://go.dev/dl/?mode=json`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**Node.js Distribution API:**
- Purpose: Fetch latest Node.js LTS version.
- Endpoint: `https://nodejs.org/dist/index.json`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**Python End-of-Life API:**
- Purpose: Fetch latest Python version.
- Endpoint: `https://endoflife.date/api/python.json`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**PyPI JSON API:**
- Purpose: Fetch latest `uv` version (fallback).
- Endpoint: `https://pypi.org/pypi/uv/json`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**Tailscale Package API:**
- Purpose: Fetch latest Tailscale version.
- Endpoint: `https://pkgs.tailscale.com/stable/?mode=json`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**Rust Stable Channel:**
- Purpose: Fetch latest Rust version (fallback).
- Endpoint: `https://static.rust-lang.org/dist/channel-rust-stable.toml`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**Composer Download Page:**
- Purpose: Fetch latest Composer version.
- Endpoint: `https://getcomposer.org/download/`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

**ipify API:**
- Purpose: Detect WAN IP for status display.
- Endpoint: `https://api.ipify.org`
- Client: `curl` in `fu.sh`.
- Auth: None.
- Direction: Outbound (read-only).

## Installer Script Sources (Downloaded & Executed)

**Docker:**
- Source: `https://get.docker.com` — Official Docker convenience script.
- Alpine exception: Uses `apk add docker docker-cli-compose` instead.

**Rust (rustup):**
- Source: `https://sh.rustup.rs` — Official rustup installer.

**NVM:**
- Source: `https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh` — Official NVM installer.

**Bun:**
- Source: `https://bun.sh/install` — Official Bun installer.

**uv:**
- Source: `https://astral.sh/uv/install.sh` — Official uv installer.

**Tailscale:**
- Source: `https://tailscale.com/install.sh` — Official Tailscale installer (Linux only).

**OpenCode:**
- Source: `https://opencode.ai/install` — Official OpenCode installer.
- Fallback: `npm i -g opencode-ai`.

## Data Storage

**Databases:**
- None — No database used by the project itself.

**File Storage:**
- Local filesystem only.
- Token file: `~/.config/dev-fu/github-token` (mode 600).
- Prompt files: `~/.fancy-prompt.sh`, `~/.fancy-prompt-blue.sh`.
- RC modifications: `~/.bashrc` or `~/.zshrc` (shell configuration).
- Temporary downloads: `/tmp/` (install scripts downloaded, executed, then deleted).

**Caching:**
- None — Version checks are live HTTP requests each time.

## Authentication & Identity

**Auth Provider:**
- Custom — GitHub Personal Access Token (PAT).
- Implementation: User manually creates a PAT at `https://github.com/settings/tokens` and enters it via interactive prompt (option 4). Token is stored locally in `~/.config/dev-fu/github-token` with `chmod 600` permissions.
- Scope: `public_repo` is sufficient for version checks.
- Used exclusively for increasing GitHub API rate limits.

## Monitoring & Observability

**Error Tracking:**
- None — Errors are displayed inline with color-coded `✗` markers and `echo -e` to stderr.

**Logs:**
- Console output only — All operations print status to stdout/stderr with ANSI color codes.
- `npm_error.log` file exists in repo root (appears to be a historical debugging artifact, not part of normal operation).

## CI/CD & Deployment

**Hosting:**
- GitHub — `https://github.com/C-Fu/dev-fu`
- Branch: `main`
- No CI/CD pipeline detected.

**Distribution:**
- Users download and execute scripts directly via `curl | bash` pattern.
- No build/publish step.

## Environment Configuration

**Required env vars:**
- None required to run the project itself.
- Runtime sets: `PATH` modifications for `~/.local/bin`, `~/.bun/bin`, `~/.cargo/bin`, `~/.nvm/versions/node/*/bin`.

**Secrets location:**
- `~/.config/dev-fu/github-token` — User-provided GitHub PAT.

## Webhooks & Callbacks

**Incoming:**
- None.

**Outgoing:**
- None (only REST API calls and script downloads).

## Local Development Server

**web.sh:**
- Python 3 threaded HTTP server.
- Listens on `0.0.0.0:18765` (configurable via `PORT` env var).
- Serves `fu.sh` with `Cache-Control: no-cache` headers.
- Purpose: Serve the script over LAN for testing on other devices.
- Protocol: HTTP/1.1 over TCP.

---

*Integration audit: 2026-05-22*
