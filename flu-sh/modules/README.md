# Module Scripts — flu.sh v1.1

This directory contains the module scripts that flu.sh fetches and executes on demand. Each script maps to an `action_id` from `menu.db`.

## Action ID Registry

| action_id | Script | Tool | Operation |
|-----------|--------|------|-----------|
| `status_check` | `status_check.sh` | Status Check | display |
| `status_check_compare` | `status_check_compare.sh` | Compare With Latest | display |
| `upgrade_all` | `upgrade_all.sh` | Upgrade All Tools | install |
| `install_go` | `install_go.sh` | Go | install |
| `remove_go` | `remove_go.sh` | Go | remove |
| `install_rust` | `install_rust.sh` | Rust | install |
| `remove_rust` | `remove_rust.sh` | Rust | remove |
| `install_python` | `install_python.sh` | Python + Pip + UV + Pipx | install |
| `remove_python` | `remove_python.sh` | Python | remove |
| `install_nvm_node` | `install_nvm_node.sh` | NVM + Node LTS | install |
| `remove_nvm_node` | `remove_nvm_node.sh` | NVM + Node | remove |
| `install_bun` | `install_bun.sh` | Bun | install |
| `remove_bun` | `remove_bun.sh` | Bun | remove |
| `install_php_laravel` | `install_php_laravel.sh` | PHP + Laravel | install |
| `remove_php_laravel` | `remove_php_laravel.sh` | PHP + Laravel | remove |
| `install_yarn` | `install_yarn.sh` | Yarn | install |
| `remove_yarn` | `remove_yarn.sh` | Yarn | remove |
| `install_docker` | `install_docker.sh` | Docker | install |
| `remove_docker` | `remove_docker.sh` | Docker | remove |
| `install_tailscale` | `install_tailscale.sh` | Tailscale | install |
| `remove_tailscale` | `remove_tailscale.sh` | Tailscale | remove |
| `install_opencode_gsd` | `install_opencode_gsd.sh` | OpenCode + GSD + OpenChamber | install |
| `create_fancy_prompt` | `create_fancy_prompt.sh` | Fancy Prompt (Purple-Pink) | install |
| `remove_fancy_prompt` | `remove_fancy_prompt.sh` | Fancy Prompt (Purple-Pink) | remove |
| `create_fancy_prompt_blue` | `create_fancy_prompt_blue.sh` | Fancy Prompt (Shades of Blue) | install |
| `remove_fancy_prompt_blue` | `remove_fancy_prompt_blue.sh` | Fancy Prompt (Blue) | remove |
| `install_avahi` | `install_avahi.sh` | Hostname Discovery (Linux) | install |
| `remove_avahi` | `remove_avahi.sh` | Hostname Discovery | remove |
| `set_github_token` | `set_github_token.sh` | GitHub Token | configure |
| `configure_mouse_disable` | `configure_mouse_disable.sh` | Mouse Reporting | configure |
| `configure_mouse_enable` | `configure_mouse_enable.sh` | Mouse Reporting | configure |
| `install_lazygit` | `install_lazygit.sh` | lazygit | install |
| `remove_lazygit` | `remove_lazygit.sh` | lazygit | remove |
| `install_starship` | `install_starship.sh` | Starship | install |
| `remove_starship` | `remove_starship.sh` | Starship | remove |
| `install_zoxide` | `install_zoxide.sh` | zoxide | install |
| `remove_zoxide` | `remove_zoxide.sh` | zoxide | remove |
| `install_eza` | `install_eza.sh` | eza | install |
| `remove_eza` | `remove_eza.sh` | eza | remove |

**Total: 55 module scripts** (30 install, 17 remove, 2 display, 2 create, 2 configure, 1 set, 1 upgrade)

## Module Script Contract

### Required Metadata Header

Every module script MUST start with this comment block (parsed by `flu_module_parse_metadata`):

```sh
#!/usr/bin/env sh
# @name: <Human-readable tool name>
# @params: <semicolon-delimited param specs or empty>
# @platforms: <comma-separated: linux, darwin>
# @version: <semver>
# @deps: <comma-separated required commands or empty>
# @timeout: <seconds, default 300>
```

### Available Environment Variables

`flu_module_set_env()` exports these before execution:

| Variable | Description |
|----------|-------------|
| `FLU_OS` | `linux` or `darwin` |
| `FLU_DISTRO` | Distro ID from /etc/os-release (e.g., `ubuntu`, `alpine`, `arch`) |
| `FLU_PKG_MGR` | Detected package manager: `apt`, `apk`, `dnf`, `pacman`, `zypper`, `brew` |
| `FLU_ARCH` | CPU architecture from `uname -m` |
| `FLU_IS_WSL` | `1` if running under WSL, `0` otherwise |
| `FLU_IS_TERMUX` | `1` if running under Termux, `0` otherwise |
| `FLU_IS_ROOT` | `1` if running as root (EUID 0), `0` otherwise |

### Runtime Contract

- `set -eu` strict mode at top (after header comments)
- Fallback package manager detection: if `FLU_PKG_MGR` is empty or unset, auto-detect
- `_maybe_sudo()` helper: use sudo unless running as root or no sudo available
- `_pkg_install()`, `_pkg_update()`, `_pkg_remove()` helpers: dispatch on `FLU_PKG_MGR`
- **Install modules (D-08):** Check if tool is already installed (command -v or file check). If yes, print version/status and exit 0 (idempotent).
- **Remove modules (D-08):** Check if tool exists before attempting removal. Print confirmation message. Exit 0 if already absent.
- **Output:** stdout for success messages, stderr for errors
- **Exit codes:** 0 on success, 1 on failure
- **Parameters (MODL-08):** Module receives `_flu_module_args` as `--key value` pairs after `--` in the argument list. Parse with: `while [ $# -gt 0 ]; do case "$1" in --key) value="$2"; shift 2;; *) shift;; esac; done`

### Naming Convention

- `install_<tool>.sh` — Install a tool (matching fu.sh function name)
- `remove_<tool>.sh` — Remove a tool (matching fu.sh function name)
- `create_<thing>.sh` — Create/apply configuration (shell prompts)
- `status_check.sh` — Display-only diagnostic (no system modification)
- `set_<setting>.sh` — Configure a setting
- `configure_<action>.sh` — Toggle/enable/disable
- `upgrade_all.sh` — Batch operation

### fu.sh Reference Mapping

Each module script extracts its install/remove logic from the corresponding fu.sh function:

| Module Script | Fu.sh Reference Function | Lines |
|---------------|--------------------------|-------|
| `install_go.sh` | `install_go()` | 1534-1558 |
| `remove_go.sh` | `remove_go()` | 1559-1571 |
| `install_rust.sh` | `install_rust()` | 1572-1595 |
| `remove_rust.sh` | `remove_rust()` | 1596-1606 |
| `install_python.sh` | `install_python()` | 1607-1657 |
| `remove_python.sh` | `remove_python()` | 1658-1673 |
| `install_nvm_node.sh` | `install_nvm_node()` | 1674-1732 |
| `remove_nvm_node.sh` | `remove_nvm_node()` | 1733-1752 |
| `install_bun.sh` | `install_bun()` | 1753-1776 |
| `remove_bun.sh` | `remove_bun()` | 1777-1787 |
| `install_yarn.sh` | `install_yarn()` | 1788-1811 |
| `remove_yarn.sh` | `remove_yarn()` | 1812-1864 |
| `install_docker.sh` | `install_docker()` | 485-520 |
| `remove_docker.sh` | `remove_docker()` | 521-554 |
| `install_avahi.sh` | `install_avahi()` | 555-635 |
| `remove_avahi.sh` | `remove_avahi()` | 636-688 |
| `create_fancy_prompt.sh` | `create_fancy_prompt()` | 1137-1159 |
| `remove_fancy_prompt.sh` | `remove_fancy_prompt()` | 1160-1173 |
| `create_fancy_prompt_blue.sh` | `create_fancy_prompt_blue()` | 1174-1196 |
| `remove_fancy_prompt_blue.sh` | `remove_fancy_prompt_blue()` | 1197-1213 |
| `status_check.sh` | `status_check()` | 1214-1319 |
| `status_check_compare.sh` | `status_check_compare()` | 1320-1533 |
| `upgrade_all.sh` | `upgrade_all()` | 1865-2016 |
| `install_tailscale.sh` | `install_tailscale()` | 2017-2048 |
| `remove_tailscale.sh` | `remove_tailscale()` | 2049-2078 |
| `install_opencode_gsd.sh` | `install_opencode_gsd()` | 2079-2249 |
| `install_php_laravel.sh` | `install_php_laravel()` | 2265-... |
| `set_github_token.sh` | `set_github_token()` | 441-484 |
| `install_lazygit.sh` | New (no fu.sh equivalent) | — |
| `remove_lazygit.sh` | New (no fu.sh equivalent) | — |
| `install_starship.sh` | New (no fu.sh equivalent) | — |
| `remove_starship.sh` | New (no fu.sh equivalent) | — |
| `install_zoxide.sh` | New (no fu.sh equivalent) | — |
| `remove_zoxide.sh` | New (no fu.sh equivalent) | — |
| `install_eza.sh` | New (no fu.sh equivalent) | — |
| `remove_eza.sh` | New (no fu.sh equivalent) | — |

`remove_php_laravel.sh`, `configure_mouse_disable.sh`, `configure_mouse_enable.sh` have no direct fu.sh equivalent — implement based on package manager removal patterns.
