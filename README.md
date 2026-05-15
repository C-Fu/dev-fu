# dev-fu — One command to bootstrap a developer machine

**One command to bootstrap a complete developer machine, anywhere.**

```bash
# Run Dev-Fu/fu.sh
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

## Why dev-fu

- **Zero dependencies** — Pure Bash 4+ and PowerShell 5.1+. No Python, no Node, no framework required to run the script itself. Everything it installs is fetched from official sources.
- **Runs everywhere** — Same script works across WSL2, Linux, macOS, and Windows (PowerShell). Supports x86, x64, ARM (Raspberry Pi, Apple Silicon), and bare metal. Tested in LXC containers and VMs. Compatible with Bash and ZSH on Unix, PowerShell on Windows.
- **Multi-distro** — Auto-detects your package manager (apk, apt, dnf, pacman, zypper, brew, winget, choco). Works on Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, and Windows.
- **Multi-select menu** — Select multiple operations in one pass. Batch install Go, Rust, and Python without re-running the script.
- **Atomic operations** — Each install has a matching remove. Every operation confirms before proceeding.

## Supported Platforms

| Platform | Architecture | Package Manager | Script |
|----------|-------------|-----------------|--------|
| Alpine Linux | x86_64, ARM | apk | `fu.sh` |
| Debian / Ubuntu | x86_64, ARM | apt | `fu.sh` |
| Fedora / RHEL | x86_64, ARM | dnf | `fu.sh` |
| Arch Linux | x86_64, ARM | pacman | `fu.sh` |
| openSUSE | x86_64, ARM | zypper | `fu.sh` |
| macOS (Intel & Apple Silicon) | x64, ARM | Homebrew | `fu.sh` |
| WSL2 (Ubuntu, Debian) | x86_64, ARM | apt | `fu.sh` |
| LXC / LXD containers | x86_64, ARM | auto-detected | `fu.sh` |
| Bare metal servers | x86_64, ARM | auto-detected | `fu.sh` |
| Raspberry Pi (Pi OS, Ubuntu) | ARM | apt | `fu.sh` |
| Windows (native) | x64, ARM | winget / choco | `fu.ps1` |

## What Can Be Installed

| Category | Tools |
|----------|-------|
| **Containers** | [Docker](https://www.docker.com/) |
| **Networking** | [Avahi Daemon](https://github.com/lathiat/avahi) + [systemd-resolved](https://www.freedesktop.org/wiki/Software/systemd/resolved/) — mDNS/NSS hostname discovery + DNS (Linux only) |
| **Languages** | [Go](https://go.dev/), [Rust](https://www.rust-lang.org/), [Python](https://www.python.org/) (with pip, pipx, uv), [Node.js](https://nodejs.org/) (LTS via nvm), [PHP](https://www.php.net/) |
| **Runtimes** | [Bun](https://bun.sh/) |
| **Package Managers** | [Yarn](https://yarnpkg.com/), [Composer](https://getcomposer.org/) (PHP), npm |
| **Web Dev** | [Laravel](https://laravel.com/) installer (via Composer) |
| **AI Tools** | [OpenCode](https://github.com/anomalyco/opencode), [GSD](https://github.com/rokicool/gsd-opencode) (Rokicool), [OpenChamber](https://github.com/rokicool/openchamber) |
| **Productivity** | [Fancy Prompt](https://github.com/jonathan-scholbach/fancy-prompt) — optional shell enhancement |
| **Terminal** | Disable mouse reporting — prevents terminal mouse events from interfering with CLI tools |

## Prerequisites

- POSIX-compatible shell (bash, zsh) — or PowerShell 5.1+ on Windows
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

Run `./fu.sh` and select options from the interactive menu:

```
 1) 🔍  Status Check
 2) ⬆️  Upgrade All Tools
 3) 🐳  Install Docker
 4) ✨  Create Fancy Prompt
 5) 🌐  Install Hostname Discovery (Linux only)
 6) 🐹  Install Go
 7) ☢️  Install Rust
 8) 🐍  Install Python + Pip + UV + Pipx
 9) 📦  Install NVM + Node LTS
10) 🥟  Install Bun
11) ⚡  Install Yarn
12) 🐁  Disable Mouse Reporting in Terminal
13) 🐘  Install PHP + Laravel
14) 🚀  Install OpenCode + GSD (Rokicool) + OpenChamber
```

- **Multi-select:** Enter comma or space-separated numbers (e.g. `6,7,8` to install Go, Rust, and Python together)
- **Remove:** Prefix with `-` (e.g. `-3` to remove Docker)
- **Upgrade all:** Press `u` at the prompt
- **Quit:** Press `q`

Single-select options (Hostname Discovery, OpenCode+GSD) must be used alone.

## Platform-Specific Notes

### Linux

All package managers supported. The script auto-detects your package manager.

Option 5 (Hostname Discovery) installs `avahi-daemon` for mDNS/NSS and `systemd-resolved` for DNS resolution, then symlinks `/etc/resolv.conf` to systemd-resolved's stub. This option is Linux-only — not available on macOS, Windows, or WSL.

### macOS

- Requires Homebrew: `brew install bash`
- Node via nvm, not system Node

### WSL2

- Run inside WSL Linux environment, not Windows
- Works with Docker Desktop WSL2 backend

### Windows (PowerShell)

For native Windows, use `fu.ps1`:

```powershell
# Option 1: Clone and run locally
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
.\fu.ps1

# Option 2: Run directly from remote (bypasses execution policy)
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1 | Invoke-Expression

# Option 3: Bypass execution policy for local script
powershell -ExecutionPolicy Bypass -File .\fu.ps1
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
