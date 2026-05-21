# dev-fu — One command to bootstrap a developer machine ([Bahasa Melayu version](README.ms-MY.md))

**One command to bootstrap a complete (kinda) developer machine, anywhere.**

```bash
# Linux / macOS / WSL2 (bash, zsh, ash, sh — just needs bash installed)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```powershell
# Windows (PowerShell) — bypasses execution policy for unsigned scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Why dev-fu

- **Zero dependencies** — Pure Bash 4+ and PowerShell 5.1+. No Python, no Node, no framework required to run the script itself. Everything it installs is fetched from official sources.
- **Runs everywhere** — Same script works across WSL2, Linux, macOS, Chromebooks, Android (Termux), and Windows (PowerShell). Supports x86, x64, ARM (Raspberry Pi, Apple Silicon), and bare metal. Tested in LXC containers, VMs, and ChromeOS Crostini. Compatible with Bash and ZSH on Unix, PowerShell on Windows.
- **Multi-distro** — Auto-detects your package manager (apk, apt, dnf, pacman, zypper, brew, winget, choco). Works on Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, ChromeOS, Android (Termux), and Windows.
- **Multi-select menu** — Select multiple operations in one pass. Batch install Go, Rust, and Python without re-running the script.
- **Atomic operations** — Each install has a matching remove. Every operation confirms before proceeding.

## Supported Platforms

<p align="center">
  <img src="https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/WSL2-4A4A4A?style=for-the-badge&logo=windows-terminal&logoColor=white" alt="WSL2">
  <img src="https://img.shields.io/badge/Chromebook-4285F4?style=for-the-badge&logo=google-chrome&logoColor=white" alt="Chromebook">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <br>
  <img src="https://img.shields.io/badge/Alpine-0D597F?style=for-the-badge&logo=alpine-linux&logoColor=white" alt="Alpine">
  <img src="https://img.shields.io/badge/Debian-A80030?style=for-the-badge&logo=debian&logoColor=white" alt="Debian">
  <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/Fedora-294172?style=for-the-badge&logo=fedora&logoColor=white" alt="Fedora">
  <img src="https://img.shields.io/badge/Arch-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white" alt="Arch">
  <br>
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/ZSH-4EAA25?style=for-the-badge&logo=zsh&logoColor=white" alt="ZSH">
  <img src="https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="PowerShell">
  <br>
  <img src="https://img.shields.io/badge/x86__64-6DB33F?style=for-the-badge&logo=amd&logoColor=white" alt="x86_64">
  <img src="https://img.shields.io/badge/ARM64-00C1DE?style=for-the-badge&logo=arm&logoColor=white" alt="ARM64">
  <img src="https://img.shields.io/badge/Raspberry_Pi-C51A4A?style=for-the-badge&logo=raspberry-pi&logoColor=white" alt="Raspberry Pi">
  <img src="https://img.shields.io/badge/LXC-4A4A4A?style=for-the-badge&logo=linux-containers&logoColor=white" alt="LXC">
</p>

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
| Chromebook (Crostini) | x86_64, ARM | apt (auto-detected) | `fu.sh` |
| Android / Termux | ARM, x86_64 | pkg (apt) | `fu.sh` |
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
| **Diagnostics** | Status Check — shows installed tools and versions; Compare With Latest — fetches latest versions from GitHub/npm/go.dev/nodejs.org and shows which tools need updating |

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
bash fu.sh

# Option 2: Run directly from remote (no clone needed)
# Works from any shell (sh, ash, zsh, fish) — just needs bash installed
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```powershell
# Windows (PowerShell) — bypasses execution policy
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Usage

Run `./fu.sh` and select options from the interactive menu:

```
 1) 🔍  Status Check
 2) 🔄  Compare With Latest
 3) ⬆️  Upgrade All Tools
 4) 🔑  Set GitHub Token
 5) 🐳  Install Docker
 6) ✨  Create Fancy Prompt (Purple-Pink)
 7) 💎  Create Fancy Prompt (Shades of Blue)
 8) 🌐  Install Hostname Discovery (Linux only)
 9) 🐹  Install Go
10) ☢️  Install Rust
11) 🐍  Install Python + Pip + UV + Pipx
12) 📦  Install NVM + Node LTS
13) 🥟  Install Bun
14) ⚡  Install Yarn
15) 🐁  Disable Mouse Reporting in Terminal
16) 🐘  Install PHP + Laravel
17) 🔒  Install Tailscale
18) 🚀  Install OpenCode + GSD (Rokicool) + OpenChamber
```

- **Multi-select:** Enter comma or space-separated numbers (e.g. `7,8 9` to install Go, Rust, and Python together)
- **Remove:** Prefix with `-` (e.g. `-4` to remove Docker)
- **Compare versions:** Option 2 fetches latest versions online and compares with your local installs
- **Upgrade all:** Press `u` at the prompt
- **Quit:** Press `q`

Single-select options (Hostname Discovery, OpenCode+GSD) must be used alone.

## Platform-Specific Notes

### Linux

All package managers supported. The script auto-detects your package manager.

Option 7 (Hostname Discovery) installs `avahi-daemon` for mDNS/NSS and `systemd-resolved` for DNS resolution, then symlinks `/etc/resolv.conf` to systemd-resolved's stub. This option is Linux-only — not available on macOS, Windows, or WSL.

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
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression

# Option 3: Bypass execution policy for local script
powershell -ExecutionPolicy Bypass -File .\fu.ps1
```

**Note:** If you see a "not digitally signed" error, use Option 2 or 3 above.

### ARM (Apple Silicon, Raspberry Pi)

- ARM builds supported for all tools
- Bun, Go, Rust have native ARM binaries

### Chromebook (ChromeOS Crostini)

- Enable Linux (Crostini) in ChromeOS Settings > Advanced > Developers
- Debian-based container with `apt` — all tools work
- Docker runs in the Crostini VM (no nested virtualization needed)
- Option 7 (Hostname Discovery) may not work if systemd is not available

### Android (Termux)

- Install [Termux](https://termux.dev/) from F-Droid or GitHub releases
- Uses `pkg` (apt-based) as the package manager
- No `sudo` needed — Termux runs as a single user
- Option 7 (Hostname Discovery) not available (no systemd)
- Some tools (Docker, PHP) have limited support on Android

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
