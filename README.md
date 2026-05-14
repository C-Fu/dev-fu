# fu.sh — One command to bootstrap a developer machine

**One command to bootstrap a complete developer machine, anywhere.**

```
# Run Dev-Fu/fu.sh
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```


## Supported Platforms

- Linux (x86_64, ARM/aarch64)
  - Debian / Ubuntu (apt)
  - Fedora / RHEL (dnf)
  - Arch Linux (pacman)
  - openSUSE (zypper)
- macOS (Intel & Apple Silicon) — Homebrew
- Windows (WSL2) — Ubuntu, Debian

## What Can Be Installed

| Category | Tools |
|----------|-------|
| **Containers** | [Docker](https://www.docker.com/) |
| **Networking** | [Avahi Daemon](https://github.com/lathiat/avahi) + [systemd-resolved](https://www.freedesktop.org/wiki/Software/systemd/resolved/) — mDNS/NSS hostname discovery + DNS (Linux only) |
| **Languages** | [Go](https://go.dev/), [Rust](https://www.rust-lang.org/), [Node.js](https://nodejs.org/) (LTS via nvm), [Python](https://www.python.org/) (with pipx, uv), [PHP](https://www.php.net/) |
| **Runtimes** | [Bun](https://bun.sh/) (JavaScript), [Composer](https://getcomposer.org/) (PHP) |
| **Package Managers** | [Yarn](https://yarnpkg.com/) (bundled with Dev Tools), npm |
| **Web Dev** | [Laravel](https://laravel.com/) installer (via Composer) |
| **AI Tools** | [OpenCode](https://github.com/anomalyco/opencode), [Get-Shit-Done (GSD)](https://github.com/rokicool/gsd-opencode) |
| **Productivity** | [Fancy Prompt](https://github.com/jonathan-scholbach/fancy-prompt) — optional shell enhancement |

## Prerequisites

- POSIX-compatible shell (bash, zsh)
- curl or wget for downloads
- sudo privileges (for system package installs)
- Internet connection

**NOTE:** For WSL2, run inside the Linux distribution, not PowerShell.

## Quick Start

```bash
# Option 1: Clone and run
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
./fu.sh

# Option 2: Run directly from remote (no clone needed)
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

## Usage

Run `./fu.sh` and select options from the menu:

```
1) Install Docker          1a) Remove Docker
2) Create Fancy Prompt    2a) Remove Fancy Prompt
3) Install Hostname Discovery   3a) Remove Hostname Discovery
4) Status Check
5) Install Dev Tools       5a) Uninstall Dev Tool
6) Install OpenCode + GSD  6a) Remove OpenCode
                          6b) Remove GSD
7) Install PHP + Laravel  7a) Uninstall PHP + Laravel
```

Select an option by number (e.g., `5` to install dev tools).

## Platform-Specific Notes

### Linux

All package managers supported. The script auto-detects your package manager.

Option 3 (Hostname Discovery) installs `avahi-daemon` for mDNS/NSS and `systemd-resolved` for DNS resolution, then symlinks `/etc/resolv.conf` to systemd-resolved's stub. This option is Linux-only — not available on macOS, Windows, or WSL.

### macOS

- Requires Homebrew: `brew install bash`
- Node via nvm, not system Node

### WSL2

- Run inside WSL Linux environment, not Windows
- Works with Docker Desktop WSL2 backend

### Windows (PowerShell)

For native Windows, use `windows/fu.ps1`:

```powershell
# Option 1: Clone and run locally
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu\windows
.\fu.ps1

# Option 2: Run directly from remote (bypasses execution policy)
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/windows/fu.ps1 | Invoke-Expression

# Option 3: Bypass execution policy for local script
powershell -ExecutionPolicy Bypass -File .\windows\fu.ps1
```

**Note:** If you see a "not digitally signed" error, use Option 2 or 3 above.

### ARM (Apple Silicon, Raspberry Pi)

- ARM builds supported for all tools
- Bun, Go, Rust have native ARM binaries

## Troubleshooting

### "command not found"

Some tools install to `~/.cargo/bin`, `~/.bun/bin`, or `~/.nvm/versions/node/`. Add to PATH:

```bash
source ~/.cargo/env    # Rust
export PATH="$HOME/.bun/bin:$PATH"  # Bun
source ~/.nvm/nvm.sh   # Node
```

### Permission denied

```bash
chmod +x fu.sh
```

### Network issues

The script includes retry logic (3 attempts, 2s delay). For manual installs,
see individual tool installation docs.

## Exit Codes

- 0 — Success
- 1 — Error (check error message for hint)
- 2 — Invalid option

## License

MIT
