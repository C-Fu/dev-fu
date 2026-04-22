# dev-fu — Environment Setup Utility

## Overview

`fu.sh` is a Bash/Zsh script designed to automate the installation and configuration of a basic development environment. It provides a menu-driven interface to install tools, configure prompts, check system status, and manage developer utilities.

The script is compatible with:

- **WSL2**
  
- **Linux (and LXC)**
  
- **ZSH on macOS**
  

## Features

### 1. Install Docker 🐳

- Installs Docker using the official installation script.
  
- Skips installation if Docker is already present.
  

### 2. Fancy Prompt ✨

- Downloads and sets up a custom fancy prompt.
  
- Option to remove the fancy prompt and restore defaults.
  

### 4. Status Check 🔍

- Verifies installation and versions of key developer tools:
  
  - Docker, Go, Rust (rustc, cargo, rustup), Bun, Node.js, Python, pip, pipx, uv
    
  - NVM and Unzip
    
- Detects **OpenCode** and **GSD** availability:
  
  - Checks for `opencode` binary or npm global package.
    
  - Checks for `gsd-opencode` globally or via `npx`.
    

### 5. Install Dev Tools 🛠️

- Installs Go, Rust, Bun, Node.js (LTS), Python, pipx, and uv.
  
- Configures environment variables for Rust, Bun, and NVM.
  

### 5a. Uninstall Dev Tool

- Removes selected developer tools (Rust, Node, Bun, Python, Go, pipx, uv).

### 6. OpenCode + GSD 🚀

- Installs **OpenCode** via curl or npm.
  
- Installs **GSD** using `npx gsd-opencode@latest`.
  
- Disables mouse reporting permanently.
  

### 6a. Remove OpenCode

- Uninstalls OpenCode (npm global package).

### 6b. Remove GSD

- Runs `gsd-opencode uninstall` to remove GSD.

## Usage

1. Clone the repository:
  
  ```
  git clone https://github.com/C-Fu/dev-fu.git
  cd dev-fu
  ```
  
2. Make the script executable:
  
  ```
  chmod +x fu.sh
  ```
  
3. Run the script:
  
  ```
  ./fu.sh
  ```
  
4. Use the interactive menu to select options.
  

## Run Directly with curl

You can run `fu.sh` directly from the repository without cloning:

```
curl -fsSL https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/fu.sh | bash
```

## Menu Options

```
1) 🐳  Install Docker
2) ✨  Create Fancy Prompt
   2a) Remove Fancy Prompt
4) 🔍  Status Check (Docker, Go, Rust, Node, Python, Bun, etc.)
5) 🛠️  Install Dev Tools (Go, Rust, Bun, Node LTS, Python)
   5a) Uninstall Dev Tool
6) 🚀  Install OpenCode and Get-Shit-Done
   6a) Remove OpenCode
   6b) Remove GSD
q) Quit
```

## Notes

- The script uses `apt-get` for package installation (Debian/Ubuntu-based systems).
  
- For macOS, ensure Homebrew or equivalent package manager is available for dependencies.
  
- OpenCode and GSD detection logic has been improved to check both binaries and npm installs.
  

## Author

Created by **C-Fu** for streamlined developer environment setup.
