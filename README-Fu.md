# fu.sh — Monolithic Dev Environment Bootstrap ([Bahasa Melayu](README-Fu.ms-MY.md))

> 📖 **This is the legacy documentation.** For the main project, see [README.md](README.md) — the flu.sh modular TUI system.

## Quick Start (curl-pipe-bash)

```bash
# fu.sh — monolithic (bash / zsh)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```sh
# sh / ash / BusyBox (no process substitution)
curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh
```

```powershell
# Windows (PowerShell) — bypasses execution policy for unsigned scripts
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.ps1?t=$(Get-Date -Format s) | Invoke-Expression
```

## Screenshot

```
://─────────────── System Info ────────────────║
│ Architecture: x86_64
│ OS: alpine
│ Package Mgr: apk
│ Shell: bash
│ WAN IP:
│ LAN IP:
│ Hostname:
│ User: root (0:0)
▉════════════════by═C-Fu════════════════


        ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗
 ██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║
 ╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║
 ██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║
 ╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝
    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝

://─────────────────────────────║
│ Environment Setup Utility
▉══════════════════════════

│ 1)  🔍  Status Check
│ 2)  🔄  Compare With Latest
│ 3)  ⬆️  Upgrade All Tools
│ 4)  🔑  Set GitHub Token
│ 5)  🐳  Install Docker
│ 6)  ✨  Create Fancy Prompt (Purple-Pink)
│ 7)  💎  Create Fancy Prompt (Shades of Blue)
│ 8)  🌐  Install Hostname Discovery (Linux only)
│ 9)  🐹  Install Go
│ 10) ☢️  Install Rust
│ 11) 🐍  Install Python + Pip + UV + Pipx
│ 12) 📦  Install NVM + Node LTS
│ 13) 🥟  Install Bun
│ 14) ⚡  Install Yarn
│ 15) 🐁  Disable Mouse Reporting in Terminal
│ 16) 🐘  Install PHP + Laravel
│ 17) 🔒  Install Tailscale
│ 18) 🚀  Install OpenCode + GSD (Rokicool) + OpenChamber

  Enter your selected options, split by commas or spaces (1,2 3 4)
  Enter -N to remove (e.g. -3 removes Docker)

://─────────────────────────║
│  Press u to upgrade all
│  Press q to quit
▉══════════════════
▸ Choice:
```

## Quick Start

```bash
# Option 1: Clone and run
git clone https://github.com/C-Fu/dev-fu.git
cd dev-fu
bash fu.sh
```

```bash
# Option 2: bash (Linux / macOS / WSL2)
bash <(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)
```

```zsh
# Option 2: zsh (macOS default)
zsh -c 'bash <(curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)'
```

```sh
# Option 2: sh / dash (Debian default)
sh -c 'curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh'
```

```sh
# Option 2: ash / BusyBox (Alpine default)
ash -c 'curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh -o /tmp/fu.sh && bash /tmp/fu.sh'
```

```fish
# Option 2: fish
bash -c 'bash <(curl -H "Cache-Control: no-cache" -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh)'
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

## Non-Interactive (CLI) Mode

Pass option numbers as arguments to run without the interactive menu:

```bash
# Upgrade all tools
bash fu.sh u

# Install Docker and Python, remove Go
bash fu.sh 5 11 -9

# One-liner from remote
bash <(curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh) 5 11 -9
```

```powershell
# Windows: Upgrade all tools
.\fu.ps1 u

# Install Docker and Python, remove Go
.\fu.ps1 5 11 -9
```

## fu.sh vs flu.sh

| Feature | `fu.sh` | `flu.sh` |
|---------|---------|----------|
| Shell | Bash 4+ | POSIX sh (bash, zsh, dash, ash, busybox) |
| UI | Numbered list prompt | ANSI TUI with arrow-key navigation |
| Menu depth | Flat (18 options) | 3-level nested submenus |
| Architecture | Monolithic | Modular (remote on-demand scripts) |
| Module source | Inline in script | `modules/` directory (local) or GitHub (remote) |
| Notable tools | Docker, Rust, PHP, Tailscale, Fancy Prompt | Python, Node.js, Go, VS Code, Neovim, etc. |
| Install count | 18 operations | 12 modules (growing) |
