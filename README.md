# dev-fu — One command to bootstrap a developer machine ([Bahasa Melayu](README.ms-MY.md))

[![POSIX sh](https://img.shields.io/badge/POSIX-sh-4EAA25?style=flat&logo=gnu-bash&logoColor=white)](https://github.com/C-Fu/dev-fu/blob/flu.sh/flu.sh)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**`flu.sh`** is a zero-dependency, curl-pipe-bash-ready TUI menu system that fetches and executes modular install scripts on demand. Runs on any POSIX shell — bash, zsh, dash, ash, busybox — across 10+ Linux distros, macOS, WSL2, Chromebook, and Android (Termux).

> **`fu.sh`** (the original monolithic script) is still available — see [fu-sh/README-Fu.md](fu-sh/README-Fu.md).
>
> **`fust`** (Rust binary port) is also available — see [fust/README-fust.md](fust/README-fust.md).

## Quick Start

### fust (Rust binary — run without installing)

```sh
# One-liner: auto-detects OS/arch, downloads, runs. Cleans up on exit.
curl -fsSL https://github.com/C-Fu/dev-fu/releases/latest/download/run.sh | sh

# Or install permanently
curl -fsSL https://github.com/C-Fu/dev-fu/releases/latest/download/install.sh | sh

# Pin a specific version
curl -fsSL https://github.com/C-Fu/dev-fu/releases/latest/download/run.sh | FLU_VERSION=v3.0.0-alpha.3 sh
```

### flu.sh (POSIX shell — modular TUI)

```bash
# Option 1: curl-pipe-bash (bash / zsh / any POSIX shell)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu-sh/flu.sh)
```

```sh
# Option 1 alt: BusyBox / dash / ash (no process substitution)
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu-sh/flu.sh -o /tmp/flu.sh && sh /tmp/flu.sh
```

```bash
# Option 2: Clone and run locally (no network needed after clone)
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
./flu-sh/flu.sh
```

### fu.sh (Bash — original monolithic)

```bash
# Option 1: curl-pipe-bash
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/fu-sh/fu.sh)
```

```sh
# Option 2: BusyBox / dash / ash
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/fu-sh/fu.sh -o /tmp/fu.sh && sh /tmp/fu.sh
```

```bash
# Option 3: Clone and run locally
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
bash ./fu-sh/fu.sh
```

> **Windows:** Use `flu.ps1` for native PowerShell. The POSIX scripts work in WSL2 (run inside the Linux distribution, not PowerShell).

## flu.sh Features

- **Zero dependencies** — Pure POSIX `sh`. No Python, no Node, no framework needed to run the script itself.
- **ANSI TUI** — Arrow-key navigation with breadcrumb trails and magenta ASCII dev-fu logo on startup.
- **3-level nested submenus** — Category → Subcategory → Option, with keyboard shortcuts (`q` quit, `b` back).
- **Modular remote architecture** — Each menu option fetches and executes a standalone POSIX `sh` script from GitHub on demand. In local mode (`git clone`), modules run from disk — no network required.
- **POSIX sh compatible** — Tested on bash 4+, zsh, dash, ash (Alpine/BusyBox).
- **Platform detection** — Auto-detects OS, distro, package manager, and CPU architecture on startup.
- **19 operations across 5 categories** — Most install operations have a matching remove.

## flu.sh Menu Structure

```
flu.sh v1.1
├── 🔍 Diagnostics
│   ├── 🔍 Status Check
│   ├── 🔄 Compare With Latest
│   └── ⬆️  Upgrade All Tools
├── 🤖 AI Tools
│   ├── 🤖 OpenCode (install/remove)
│   ├── 🛠 GSD (Rokicool)
│   ├── 🛠 GSD (Redux)
│   ├── 🤖 Hermes Agent
│   └── 🏛 OpenChamber
├── 🐹 Languages & Runtimes
│   ├── 🐹 Go (install/remove)
│   ├── 🦀 Rust (install/remove)
│   ├── 🐍 Python + Pip + UV + Pipx (install/remove)
│   ├── 💚 NVM + Node LTS (install/remove)
│   ├── 🥟 Bun (install/remove)
│   ├── 🐘 PHP + Laravel (install/remove)
│   ├── ☕ OpenJDK (install/remove)
│   └── 🧶 Yarn (install/remove)
├── 🚀 Modern CLI
│   ├── 📦 lazygit (install/remove)
│   ├── 🚀 Starship (install/remove)
│   ├── 📁 zoxide (install/remove)
│   └── 📋 eza (install/remove)
├── 🐚 Shell
│   ├── 💜 Fancy Prompt (Purple-Pink) (create/remove)
│   ├── 💙 Fancy Prompt (Shades of Blue) (create/remove)
│   ├── 📡 Avahi Daemon / mDNS (install/remove)
│   └── 🌐 Systemd-Resolved / LLMNR (install/remove)
├── 🛠 System Tools
│   ├── 🐳 Docker (install/remove)
│   └── 🛜 Tailscale (install/remove)
└── ⚙️ Settings
    ├── 🔑 Set GitHub Token
    ├── 🖱  Disable Mouse Reporting
    └── 🖱  Enable Mouse Reporting
```

## Module Architecture

flu.sh uses a remote on-demand module system. Each menu option maps to a standalone POSIX `sh` script under `flu-sh/modules/`. When flu.sh runs:

1. **`tui.sh`** — ANSI terminal rendering primitives (cursor positioning, colors, keyboard input)
2. **`menu.sh`** — Parses `menu.db` (pipe-delimited menu DSL) and renders the interactive TUI
3. **`modules.sh`** — Handles remote script fetching from GitHub and local execution

### How Modules Work

- **Local mode:** `git clone` and run — modules are sourced from disk in `flu-sh/modules/`, no network needed
- **Remote mode:** `curl-pipe-bash` — modules are fetched on-demand from GitHub raw URLs with 3 retries (2s delay)
- **Environment:** Modules use `FLU_OS`, `FLU_DISTRO`, `FLU_PKG_MGR`, `FLU_ARCH` for platform-aware installs
- **Safety:** All modules use `set -eu`, idempotent guards (`command -v`), and `_maybe_sudo()` for privilege escalation only when needed
- **Contract:** Every module script includes a parsed metadata header (`@name`, `@platforms`, `@deps`, `@timeout`) and follows strict exit code conventions (0 = success, 1 = failure)

### Module Categories

| Category | Module Scripts | Count |
|----------|---------------|-------|
| Languages & Runtimes | `install_go.sh`, `install_rust.sh`, `install_python.sh`, `install_nvm_node.sh`, `install_bun.sh`, `install_php_laravel.sh` (+ matching remove scripts) | 12 |
| Tools | `install_docker.sh`, `install_tailscale.sh`, `install_yarn.sh`, `install_opencode_gsd.sh` (+ matching remove scripts) | 7 |
| Shell | `create_fancy_prompt.sh`, `create_fancy_prompt_blue.sh`, `install_avahi.sh` (+ matching remove scripts) | 6 |
| Diagnostics | `status_check.sh`, `status_check_compare.sh`, `upgrade_all.sh` | 3 |
| Settings | `set_github_token.sh`, `configure_mouse_disable.sh`, `configure_mouse_enable.sh` | 3 |

**Total: 31 module scripts.** See [flu-sh/modules/README.md](flu-sh/modules/README.md) for the full action ID registry and module contract specification.

### Architecture Diagram

```
curl-pipe-bash / git clone
        │
        ▼
    flu.sh ─── orchestrator
        │
   ┌────┼────────────┐
   ▼    ▼            ▼
tui.sh  menu.sh  modules.sh
   │     │           │
   │     ▼           ▼
   │  menu.db    modules/*.sh
   │  (DSL)    (on-demand fetch)
   ▼
  TTY rendering
  (ANSI escape codes)
```

## fu.sh — Legacy Monolithic Script

flu.sh is the next-generation modular TUI system. The original monolithic script `fu.sh` is still available with 18 flat-menu operations and is documented separately — see **[fu-sh/README-Fu.md](fu-sh/README-Fu.md)** for `fu.sh` documentation, including its numbered prompt interface, non-interactive CLI mode, and platform-specific notes.

| Feature | `flu.sh` | `fu.sh` |
|---------|----------|---------|
| Shell | POSIX `sh` (bash, zsh, dash, ash, busybox) | Bash 4+ |
| UI | ANSI TUI with arrow-key navigation | Numbered list prompt |
| Menu depth | 3-level nested submenus | Flat (18 options) |
| Architecture | Modular (remote on-demand scripts) | Monolithic (all logic in one file) |
| Module source | `modules/` directory (local) or GitHub (remote) | Inline functions |
| Operations | 19 across 5 categories | 18 flat operations |
| POSIX compatibility | Full (dash, ash, busybox) | Bash only |

## Why dev-fu

- **Zero dependencies** — Pure POSIX `sh` and PowerShell 5.1+. Everything it installs is fetched from official sources.
- **Runs everywhere** — Same script across 10+ Linux distros, macOS, WSL2, Chromebooks, Android (Termux), and Windows (PowerShell). Tested in LXC containers, VMs, bare metal, and ChromeOS Crostini.
- **Multi-distro** — Auto-detects 6 package managers (apk, apt, dnf, pacman, zypper, brew). Works on Alpine, Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, macOS, and Termux.
- **Modular architecture** — On-demand remote scripts in `flu.sh`. Clone and run locally for zero-network operation.
- **Batch operations** — `upgrade_all.sh` upgrades every installed tool in one pass. Status Check shows all installed versions. Compare With Latest checks for updates.

## Supported Platforms

flu.sh is POSIX `sh` compatible and tested on:

| Shell | TUI Support |
|-------|------------|
| bash 4+ | Full |
| zsh | Full |
| dash (Debian default) | Full |
| ash (Alpine/BusyBox) | Full |

| Platform | Package Manager | Architecture |
|----------|----------------|-------------|
| Alpine Linux | apk | x86_64, ARM |
| Debian / Ubuntu | apt | x86_64, ARM |
| Fedora / RHEL | dnf | x86_64, ARM |
| Arch Linux | pacman | x86_64, ARM |
| openSUSE | zypper | x86_64, ARM |
| macOS (Intel & Apple Silicon) | Homebrew | x64, ARM |
| WSL2 (Ubuntu, Debian) | apt | x86_64, ARM |
| Chromebook (Crostini) | apt | x86_64, ARM |
| Android (Termux) | pkg | ARM, x86_64 |
| Raspberry Pi (Pi OS, Ubuntu) | apt | ARM |

> **Windows native:** Use `flu.ps1` (PowerShell). For WSL2, run `flu.sh` inside the Linux distribution.

## Platform-Specific Notes

### Alpine / BusyBox

- **NVM + Node LTS** installs Node.js directly via `apk add nodejs npm` instead of NVM. Alpine's musl libc is incompatible with NVM's prebuilt Node binaries.
- **Docker** uses `apk add docker docker-cli-compose` since Docker's official install script does not support Alpine.

### macOS

- Requires [Homebrew](https://brew.sh/) — the script auto-detects `brew` as the package manager.
- Node is installed via NVM, not the system Node.

### WSL2

- Run `flu.sh` inside the WSL Linux distribution, not from PowerShell.
- Works with Docker Desktop WSL2 backend.

### Chromebook (ChromeOS Crostini)

- Enable Linux (Crostini) in ChromeOS **Settings > Advanced > Developers**.
- Debian-based container with `apt` — all tools work.
- Docker runs in the Crostini VM (no nested virtualization needed).
- Hostname Discovery may not work if systemd is not available.

### Android (Termux)

- Install [Termux](https://termux.dev/) from F-Droid or GitHub releases.
- Uses `pkg` (apt-based). No `sudo` needed — Termux runs as a single user.
- Hostname Discovery not available (no systemd).
- Some tools (Docker, PHP) have limited support on Android.

### ARM (Apple Silicon, Raspberry Pi)

- ARM builds supported for all tools. Bun, Go, Rust have native ARM binaries.

## Troubleshooting

### "command not found" after install

Some tools install to non-standard paths. Add to your shell profile:

```bash
export PATH="$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.local/bin:$PATH"
source ~/.cargo/env     # Rust
source ~/.nvm/nvm.sh    # Node.js (NVM)
```

### Terminal not restored after exit

Press `Ctrl+C` or run `reset`. flu.sh has signal-safe cleanup via `_flu_cleanup_exit()` that restores terminal settings on every exit path (normal, error, or signal).

### Module fetch fails (network error)

flu.sh retries 3 times with 2-second delays. For environments with unreliable network, clone the repo and run locally:

```bash
git clone https://github.com/C-Fu/dev-fu.git && cd dev-fu && ./flu-sh/flu.sh
```

### "No such file" on curl-pipe-bash

BusyBox and dash don't support process substitution (`<(curl ...)`). Use the alternate form:

```sh
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/flu.sh/flu-sh/flu.sh -o /tmp/flu.sh && sh /tmp/flu.sh
```

### Permission denied

```bash
chmod +x flu.sh
```

### TUI not rendering (garbled text)

Ensure your terminal supports ANSI escape codes. Most modern terminals do — try `xterm-256color` or `screen-256color` as your `TERM` setting. For very minimal environments (bare `dash` without a TTY), flu.sh falls back to a plain-text numbered prompt.

## License

MIT
