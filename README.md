# fu.sh — One command to bootstrap a developer machine

**One command to bootstrap a complete developer machine, anywhere.**

## Supported Platforms

- Linux (x86_64, ARM/aarch64)
  - Debian / Ubuntu (apt)
  - Fedora / RHEL (dnf)
  - Arch Linux (pacman)
  - openSUSE (zypper)
- macOS (Intel & Apple Silicon) — Homebrew
- Windows (WSL2) — Ubuntu, Debian

## Prerequisites

- POSIX-compatible shell (bash, zsh)
- curl or wget for downloads
- sudo privileges (for system package installs)
- Internet connection

**NOTE:** For WSL2, run inside the Linux distribution, not PowerShell.

## Quick Start

```bash
# Clone and run
git clone https://github.com/yourusername/fu.sh.git
cd fu.sh
./fu.sh
```

## Usage

Run `./fu.sh` and select options from the menu:

```
1) Install Docker          1a) Remove Docker
2) Create Fancy Prompt    2a) Remove Fancy Prompt
3) Install Avahi Daemon   3a) Remove Avahi Daemon
4) Status Check
5) Install Dev Tools       5a) Uninstall Dev Tool
6) Install OpenCode + GSD  6a) Remove OpenCode
                          6b) Remove GSD
7) Install PHP + Laravel  7a) Uninstall PHP + Laravel
```

Select an option by number (e.g., `5` to install dev tools).

## What Gets Installed

- **Docker** — Container runtime
- **Avahi Daemon** — Local network discovery (mDNS/NSS)
- **Go** — Programming language
- **Rust** — Systems programming
- **Bun** — JavaScript runtime
- **Node.js** — JavaScript runtime (LTS via nvm)
- **Python** — Programming language (python3, pipx, uv)
- **Yarn** — Package manager (bundled with Dev Tools)
- **OpenCode** — AI coding assistant
- **GSD** — Developer workflow system
- **PHP + Laravel** — PHP stack

## Platform-Specific Notes

### Linux

All package managers supported. The script auto-detects your package manager.

### macOS

- Requires Homebrew: `brew install bash`
- Node via nvm, not system Node

### WSL2

- Run inside WSL Linux environment, not Windows
- Works with Docker Desktop WSL2 backend

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