# Technology Stack

**Analysis Date:** 2026-05-22

## Languages

**Primary:**
- **Bash 4+** — Main implementation language for `fu.sh` (2629 lines). Uses Bash-specific features: associative arrays (`declare -A`), `[[ ]]` tests, `read -ra`, `${var//pat/rep}` parameter expansion, `coproc`-free TTY reattachment.

**Secondary:**
- **PowerShell 5.1+ / PowerShell 7** — Full Windows equivalent in `fu.ps1` (1971 lines). Uses `Get-Command`, `Invoke-RestMethod`, `Write-Host`, PowerShell arrays/hashes.
- **POSIX sh (dash/ash/BusyBox)** — Used in `checklist.sh` (596 lines), `menu.sh` (654 lines), `menuWSL.sh` (574 lines). Carefully avoids Bashisms; uses `eval` for dynamic variables, `dd` for key reads.
- **Fish shell** — Embedded implementation inside `checklist.sh` and `menu.sh` after `__FISH__` marker. Uses Fish-specific syntax (`set -l`, `string split`, `status --is-interactive`).
- **Python 3 (stdlib only)** — Embedded in `web.sh` (85 lines). Uses `http.server`, `socketserver`, `socket`, `signal` for a development file server.

**Supplementary:**
- **Markdown** — `README.md` (339 lines), `README.ms-MY.md` (339 lines, Bahasa Melayu translation).

## Runtime

**Environment:**
- No runtime installation required — scripts run directly via system shells.
- Bash 4+ required for `fu.sh` (uses associative arrays).
- POSIX sh fallback for `checklist.sh` and friends.

**Package Manager:**
- Not applicable — zero-dependency project. No `package.json`, `requirements.txt`, `Cargo.toml`, or `go.mod`.
- No lockfile needed.

## Frameworks

**Core:**
- None — pure shell scripting. No frameworks, libraries, or package dependencies.

**Testing:**
- Not detected — no test framework, no test files.

**Build/Dev:**
- `web.sh` — Development server (Python 3 HTTP server) for serving `fu.sh` over LAN.
- Git — Version control only.

## Key Dependencies

**Critical (Runtime — all optional, auto-detected):**
- `curl` or `wget` — Required for downloading installer scripts and fetching version info from APIs.
- `sudo` — Required for system package installs (auto-detected; skips if running as root or in Termux).
- System package manager — One of: `apt-get`, `apk`, `dnf`, `pacman`, `zypper`, `brew`, `winget`, `choco`.

**Infrastructure (Tools managed by the script — not bundled):**
- Docker — Installed via `get.docker.com` or `apk`.
- Go — Installed via system package manager.
- Rust — Installed via `rustup` from `sh.rustup.rs`.
- Python 3 + pip + uv + pipx — Installed via system package manager + `astral.sh/uv/install.sh`.
- Node.js + NVM — Installed via `nvm-sh/nvm` install script (or `apk add nodejs npm` on Alpine).
- Bun — Installed via `bun.sh/install`.
- Yarn — Installed via `npm install -g yarn`.
- PHP + Composer + Laravel — Installed via system package manager + Composer.
- Tailscale — Installed via `tailscale.com/install.sh` or Homebrew.
- OpenCode — Installed via `opencode.ai/install` or `npm i -g opencode-ai`.
- GSD (gsd-opencode) — Installed via `npx gsd-opencode@latest`.
- OpenChamber — Installed via `npm i -g @openchamber/web`.

## Configuration

**Environment:**
- No configuration files required to run the project itself.
- GitHub Personal Access Token stored at `~/.config/dev-fu/github-token` (created by option 4 in the script).
- Fancy prompt scripts written to `~/.fancy-prompt.sh` or `~/.fancy-prompt-blue.sh` (created by options 6/7).

**Build:**
- No build step — scripts are executed directly.

## Platform Requirements

**Development:**
- Any POSIX-compatible system with Bash 4+.
- Git for version control.
- No Node.js, Python, or other tooling required to develop this project.

**Production:**
- End-user runs on: Linux (x86_64, ARM), macOS (Intel, Apple Silicon), Windows (PowerShell), WSL2, ChromeOS Crostini, Android Termux.
- Supports package managers: `apt`, `apk`, `dnf`, `pacman`, `zypper`, `brew`, `winget`, `choco`, `scoop`.
- Internet connection required for tool installation and version comparison.

---

*Stack analysis: 2026-05-22*
