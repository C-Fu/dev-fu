# Architecture: Modular Shell-Script TUI Menu System

**Project:** flu.sh (dev-fu)
**Researched:** 2026-05-23
**Confidence:** HIGH (based on existing codebase analysis + lxdialog/gum/fzf architectural study)

## Executive Summary

flu.sh is a single-file, curl-pipe-bash-friendly script that embeds a portable TUI engine and a hierarchical menu system. It fetches and executes remote module scripts on demand from GitHub. The architecture separates five distinct concerns: (1) terminal rendering primitives, (2) widget types built on those primitives, (3) menu definition and navigation state, (4) module fetching and execution, and (5) the main orchestrator loop. All are organized as clearly-bounded function groups within a single file — not separate files — because the deployment constraint demands zero-local-file single-script execution. Modules are the only external component, fetched at runtime.

The design borrows from lxdialog's layered approach (shared drawing primitives → widget types), gum's pipeline philosophy (widgets read input, write selection to stdout, exit with status code), and the existing checklist.sh's proven POSIX-compatible patterns (stty/dd raw reads, eval-based item storage, dumb-terminal fallback).

---

## Recommended Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          flu.sh (single file)                        │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │  Layer 1: Utility & Platform Detection                          │ │
│  │  Colors · die() · retry_network() · detect_platform()          │ │
│  │  detect_distro() · pkg_install() · pkg_remove()                │ │
│  └─────────────────────────┬───────────────────────────────────────┘ │
│                            │                                         │
│  ┌─────────────────────────▼───────────────────────────────────────┐ │
│  │  Layer 2: TUI Engine                                            │ │
│  │  ┌──────────────────┐  ┌──────────────────────────────────────┐ │ │
│  │  │ Terminal Prims   │  │ Drawing Prims                        │ │ │
│  │  │ term_init()      │  │ draw_box() · draw_title()           │ │ │
│  │  │ term_restore()   │  │ draw_separator() · truncate_text()  │ │ │
│  │  │ read_key()       │  │ clear_region() · print_centered()   │ │ │
│  │  │ move_cursor()    │  └──────────────┬───────────────────────┘ │ │
│  │  └──────────────────┘                 │                         │ │
│  │  ┌────────────────────────────────────▼───────────────────────┐ │ │
│  │  │ Widgets                                                    │ │ │
│  │  │ menu_single() · checklist() · inputbox() · yesno()       │ │ │
│  │  │ infobox() · msgbox()                                      │ │ │
│  │  └────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────┬───────────────────────────────────────┘ │
│                            │                                         │
│  ┌─────────────────────────▼───────────────────────────────────────┐ │
│  │  Layer 3: Menu System                                           │ │
│  │  ┌──────────────────┐  ┌──────────────────────────────────────┐ │ │
│  │  │ Menu Registry    │  │ Navigation Controller                │ │ │
│  │  │ Parse menu defs  │  │ Menu stack (push/pop)               │ │ │
│  │  │ Build item tree  │  │ Breadcrumb tracking                 │ │ │
│  │  │ Lookup by tag    │  │ Back/forward logic                  │ │ │
│  │  └────────┬─────────┘  └──────────────┬───────────────────────┘ │ │
│  │           └──────────────┬─────────────┘                        │ │
│  │  ┌──────────────────────▼─────────────────────────────────────┐ │ │
│  │  │ Prompt System                                               │ │ │
│  │  │ ask_choice() · ask_text() · ask_confirm()                  │ │ │
│  │  │ Collects module arguments before execution                  │ │ │
│  │  └────────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────┬───────────────────────────────────────┘ │
│                            │                                         │
│  ┌─────────────────────────▼───────────────────────────────────────┐ │
│  │  Layer 4: Module Execution                                      │ │
│  │  fetch_module() · validate_module() · exec_module()            │ │
│  │  Cache management · Version check · Fallback strategy           │ │
│  └─────────────────────────┬───────────────────────────────────────┘ │
│                            │                                         │
│  ┌─────────────────────────▼───────────────────────────────────────┐ │
│  │  Layer 5: Main Orchestrator                                     │ │
│  │  CLI arg parse · Main menu loop · Error handling                │ │
│  │  Result display · "Press any key" flow                          │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
         │
         │ fetch + exec (subshell)
         ▼
┌──────────────────────────┐
│  Remote Module Scripts   │  (GitHub: modules/docker/install.sh)
│  Each is self-contained  │  (GitHub: modules/go/install.sh)
│  Receives env vars+args  │  (GitHub: modules/python/install.sh)
└──────────────────────────┘
```

---

## Component Boundaries

| Component | Responsibility | Communicates With | Data Contract |
|-----------|---------------|-------------------|---------------|
| **Terminal Primitives** | Raw TTY control, key reading, cursor positioning | Drawing Primitives (only) | No contract — internal helpers |
| **Drawing Primitives** | Boxes, separators, text truncation, centering | Widgets | Takes dimensions + content strings |
| **Widgets** | Interactive UI elements (menu, checklist, input, yesno) | Menu System, Prompt System | **In:** title, prompt, items via positional args. **Out:** selection to stdout, exit code (0=confirm, 1=cancel) |
| **Menu Registry** | Parse and store menu definitions, lookup by tag | Navigation Controller | Internal eval-based variables (POSIX-compatible) |
| **Navigation Controller** | Menu stack management, breadcrumb tracking, back nav | Main Orchestrator, Menu Registry | Menu tag stack, current position |
| **Prompt System** | Collect user input for module parameters | Widgets (for input UI), Module Execution | Collected values → shell arguments |
| **Module Fetcher** | Download, cache, validate remote module scripts | Module Execution | Local file path to cached script |
| **Module Execution** | Run module in subshell, capture result | Module Fetcher, Main Orchestrator | **In:** env vars + args. **Out:** exit code, stdout/stderr |
| **Main Orchestrator** | Entry point, CLI parsing, main loop, error handling | All above | Top-level control flow |
| **Utility/Platform** | Colors, error handling, platform detection, pkg abstraction | All components | Global env vars (DETECTED_OS, etc.) |

### Boundary Rules

1. **Widgets never call modules** — widgets return selection data; the orchestrator decides what to do with it.
2. **Modules never see the TUI** — they run in a subshell with a clean terminal. All prompts happen *before* module execution.
3. **Menu Registry is read-only after init** — parsed once at startup, never modified during runtime.
4. **Terminal Primitives are the only layer that touches stty/TTY** — widgets go through drawing primitives, never raw TTY.

---

## Data Flow

### Primary Request Path (Interactive)

```
User starts: bash flu.sh (or curl | bash)
    │
    ▼
[1] TTY reattach (if piped)
    │
    ▼
[2] Platform detection → sets globals
    │  DETECTED_OS, DETECTED_DISTRO, DETECTED_WSL,
    │  DETECTED_ENV, PKG_MANAGER, FLU_CACHE_DIR
    │
    ▼
[3] CLI args? ──YES──→ run_cli_mode() → exit
    │
    NO
    │
    ▼
[4] Menu Registry: parse menu definitions into memory
    │  (eval-based indexed variables, same pattern as checklist.sh)
    │
    ▼
┌──[5] Main Menu Loop ──────────────────────────────────────────────┐
│    │                                                                │
│    ▼                                                                │
│    [5a] Render current menu level via TUI Engine                    │
│          - Navigation Controller provides current menu items        │
│          - Widget renders with title, items, key hints              │
│    │                                                                │
│    ▼                                                                │
│    [5b] Read user input (key press)                                 │
│    │                                                                │
│    ├──→ Navigation key (↑↓): update cursor, re-render              │
│    │                                                                │
│    ├──→ Select (Enter): resolve selected item                       │
│    │      │                                                         │
│    │      ├──→ Item type = submenu:                                 │
│    │      │    Navigation Controller pushes submenu to stack        │
│    │      │    Loop back to [5a] with new menu                      │
│    │      │                                                         │
│    │      ├──→ Item type = module:                                  │
│    │      │    ┌────────────────────────────────────┐               │
│    │      │    │ [A] Prompt System collects vars    │               │
│    │      │    │     (if module declares prompts)   │               │
│    │      │    │ [B] Module Fetcher:                │               │
│    │      │    │     Check cache for module script  │               │
│    │      │    │     If miss: curl/wget from GitHub │               │
│    │      │    │     Validate (exit 0 on --version) │               │
│    │      │    │ [C] Execute in subshell:           │               │
│    │      │    │     export FLU_* env vars          │               │
│    │      │    │     sh <cached_script> <action>    │               │
│    │      │    │     Capture exit code + output     │               │
│    │      │    │ [D] Display result (success/fail)  │               │
│    │      │    └────────────────────────────────────┘               │
│    │      │    "Press any key to continue"                          │
│    │      │    Loop back to [5a]                                    │
│    │      │                                                         │
│    │      └──→ Item type = action:                                  │
│    │           Call local function directly (status_check, etc.)    │
│    │           Loop back to [5a]                                    │
│    │                                                                │
│    ├──→ Back (Esc/b): Navigation Controller pops stack              │
│    │         Loop back to [5a] with parent menu                     │
│    │                                                                │
│    └──→ Quit (q): exit loop                                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Data That Crosses Boundaries

```
Boundary                  │ Data Direction        │ Format
─────────────────────────┼───────────────────────┼──────────────────────
Widget → stdout          │ Selection result      │ Tag string(s), one per line
Widget → exit code       │ User intent           │ 0=confirmed, 1=cancelled
Menu Registry → Nav Ctrl │ Item lists            │ eval variables item_N_*
Nav Ctrl → Widget        │ Current menu items    │ Function args (title, items)
Prompt System → Module   │ User-collected values │ CLI args (--scope global)
Orchestrator → Module    │ Environment           │ FLU_OS, FLU_DISTRO, etc.
Module → Orchestrator    │ Result                │ Exit code + stdout text
```

---

## Menu Definition DSL

### Design Rationale

The menu structure must be declarative, easy to edit, and parseable by POSIX shell. The existing codebase uses parallel arrays — that pattern doesn't scale to hierarchical menus. A pipe-delimited line format is the right choice because:

1. **POSIX parseable** — `awk -F'|'` works everywhere, no Bash-isms
2. **Flat-file, hierarchical by convention** — parent tag prefix groups items
3. **Human-editable** — each line is one menu item, easy to add/remove
4. **grep-friendly** — filter by parent, type, or tag

### Format Specification

```sh
# Lines starting with # are comments
# Blank lines are ignored
# Lines starting with @ are metadata directives
#
# Format: PARENT:TAG|LABEL|DESCRIPTION|TYPE|REFERENCE|ICON
#
# PARENT  - menu tag this item belongs to (use "main" for root)
# TAG     - unique identifier for this item
# LABEL   - display text (shown in menu)
# DESC    - short description (shown when highlighted or as subtitle)
# TYPE    - submenu | module | action | separator | header
# REF     - for submenu: child menu tag prefix
#         - for module:  module path (e.g., "docker/install")
#         - for action:  function name (e.g., "status_check")
#         - for separator/header: (empty)
# ICON    - emoji or icon character (optional, default empty)
```

### Example Definition

```sh
# ═══ Main Menu ═══
main:header|──── dev-fu Environment Setup ────||header||
main:status|Status Check|Show installed tool versions|action|status_check|🔍
main:compare|Version Compare|Compare local vs latest|action|status_check_compare|📊
main:upgrade|Upgrade All|Update all installed tools|action|upgrade_all|⬆️
main:sep1|─── Install ───||separator||
main:install|Install Tools|Browse installable tools|submenu|install|📦
main:config|Configuration|Tokens, preferences, system config|submenu|config|⚙️

# ═══ Install Submenu ═══
install:header|──── Install Tools ────||header||
install:docker|Docker|Container platform|module|docker/install|🐳
install:go|Go|Go programming language|module|go/install|🐹
install:rust|Rust|Rust programming language|module|rust/install|🦀
install:lang|Languages|Python, Node, Bun, PHP|submenu|lang|🐍
install:net|Networking|Tailscale, Avahi|submenu|net|🌐
install:tools|CLI Tools|yarn, GSD, opencode|submenu|tools|🔧

# ═══ Languages Submenu (3rd level) ═══
lang:header|──── Programming Languages ────||header||
lang:python|Python|Python 3 + pip + venv|module|python/install|🐍
lang:node|Node.js|via nvm|module|node/install|🟢
lang:bun|Bun|Bun JavaScript runtime|module|bun/install|🍞
lang:php|PHP + Laravel|PHP with Laravel framework|module|php/install|🐘

# ═══ Config Submenu ═══
config:header|──── Configuration ────||header||
config:token|GitHub Token|Set API token for rate limits|module|github/token|🔑
config:prompt|Fancy Prompt|Customize shell prompt|submenu|prompt|🎨

# ═══ Prompt Submenu (3rd level) ═══
prompt:header|──── Shell Prompt Themes ────||header||
prompt:purple|Purple-Pink|Purple-pink gradient prompt|module|prompt/purple|💜
prompt:blue|Shades of Blue|Blue gradient prompt|module|prompt/blue|💙
```

### How It's Parsed

```sh
# Called once at startup. Reads definitions (embedded in flu.sh as heredoc
# or fetched alongside flu.sh). Stores as eval-accessible indexed variables.
_parse_menu_defs() {
    _menu_count=0
    while IFS= read -r line; do
        # Skip comments and blanks
        case "$line" in '#'*|'') continue ;; esac
        _menu_count=$((_menu_count + 1))
        _m_parent=$(printf '%s' "$line" | awk -F':' '{print $1}')
        _m_rest=$(printf '%s' "$line" | awk -F':' '{print $2}')
        _m_tag=$(printf '%s' "$_m_rest" | awk -F'|' '{print $1}')
        _m_label=$(printf '%s' "$_m_rest" | awk -F'|' '{print $2}')
        _m_desc=$(printf '%s' "$_m_rest" | awk -F'|' '{print $3}')
        _m_type=$(printf '%s' "$_m_rest" | awk -F'|' '{print $4}')
        _m_ref=$(printf '%s' "$_m_rest" | awk -F'|' '{print $5}')
        _m_icon=$(printf '%s' "$_m_rest" | awk -F'|' '{print $6}')
        eval "_mi_${_menu_count}_parent=\$_m_parent"
        eval "_mi_${_menu_count}_tag=\$_m_tag"
        eval "_mi_${_menu_count}_label=\$_m_label"
        eval "_mi_${_menu_count}_desc=\$_m_desc"
        eval "_mi_${_menu_count}_type=\$_m_type"
        eval "_mi_${_menu_count}_ref=\$_m_ref"
        eval "_mi_${_menu_count}_icon=\$_m_icon"
    done <<'MENUEOF'
main:header|──── dev-fu Setup ────||header||
main:status|Status Check|Show versions|action|status_check|🔍
...
MENUEOF
}

# Get children of a menu tag
_menu_children() {
    _parent="$1"
    _result=""
    i=1
    while [ "$i" -le "$_menu_count" ]; do
        eval "_p=\$_mi_${i}_parent"
        if [ "$_p" = "$_parent" ]; then
            eval "_t=\$_mi_${i}_type"
            case "$_t" in
                header|separator) _result="$_result $_i" ;;
                *) _result="$_result $_i" ;;
            esac
        fi
        i=$((i + 1))
    done
    printf '%s' "$_result"
}
```

### Why Not JSON/YAML/TOML

Shell scripts cannot parse these without `jq`, `yq`, or similar tools — all of which violate the zero-dependency constraint. Pipe-delimited text with awk parsing is the most portable, zero-dep approach.

---

## Module Interface Contract

### The Contract (what every module MUST implement)

```sh
#!/bin/sh
# Module: <category>/<name>
# Description: <what it does>
#
# Interface contract:
#   Called as: sh <module.sh> <action> [args...]
#   Actions:
#     install   - Install the tool
#     remove    - Uninstall the tool
#     status    - Print current installation status
#
#   Environment variables provided by flu.sh:
#     FLU_OS          - linux, macos, wsl, windows
#     FLU_DISTRO      - ubuntu, alpine, fedora, arch, etc.
#     FLU_PKG_MGR     - apt, apk, dnf, pacman, zypper, brew, winget, choco
#     FLU_WSL         - 0 or 1
#     FLU_ENV         - desktop, termux, lxc, chromebook
#     FLU_ARCH        - x86_64, aarch64, armv7l
#     FLU_BATCH       - 0 or 1 (suppress confirmations)
#     FLU_CACHE_DIR   - path to cache directory
#     FLU_HOME        - project config dir (~/.config/dev-fu)
#     FLU_VERBOSE     - 0 or 1
#
#   Exit codes:
#     0 - Success
#     1 - Failure
#     2 - Cancelled by user
#
#   Output:
#     stdout - User-facing messages (colored, with emojis)
#     stderr - Debug/diagnostic messages (suppressed unless FLU_VERBOSE=1)
```

### Example Module

```sh
#!/bin/sh
# Module: docker/install
# Description: Install or remove Docker

set -e

action="${1:-install}"

# --- Status ---
if [ "$action" = "status" ]; then
    if command -v docker >/dev/null 2>&1; then
        printf '  ✓ Docker %s\n' "$(docker --version 2>/dev/null | cut -d, -f1)"
    else
        printf '  ✗ Docker not installed\n'
    fi
    exit 0
fi

# --- Install ---
if [ "$action" = "install" ]; then
    if command -v docker >/dev/null 2>&1; then
        printf '  ✓ Docker already installed: %s\n' "$(docker --version | cut -d, -f1)"
        exit 0
    fi

    printf '  → Installing Docker...\n'

    case "$FLU_PKG_MGR" in
        apt)  curl -fsSL https://get.docker.com | sh ;;
        apk)  apk add docker ;;
        dnf)  dnf install -y docker ;;
        pacman) pacman -S --noconfirm docker ;;
        brew)  brew install docker ;;
        *)
            printf '  ✗ Unsupported package manager: %s\n' "$FLU_PKG_MGR"
            exit 1
            ;;
    esac

    printf '  ✓ Docker installed successfully\n'
    exit 0
fi

# --- Remove ---
if [ "$action" = "remove" ]; then
    case "$FLU_PKG_MGR" in
        apt)  apt remove -y docker-ce docker-ce-cli ;;
        apk)  apk del docker ;;
        dnf)  dnf remove -y docker ;;
        pacman) pacman -Rns --noconfirm docker ;;
        brew)  brew uninstall docker ;;
        *)
            printf '  ✗ Unsupported package manager: %s\n' "$FLU_PKG_MGR"
            exit 1
            ;;
    esac
    printf '  ✓ Docker removed\n'
    exit 0
fi

printf 'Unknown action: %s\n' "$action" >&2
exit 1
```

### Why Subshell Execution (not `source`)

1. **Security** — remote code is isolated; it can't pollute flu.sh's namespace or functions
2. **Crash containment** — a module's `set -e` or `exit` won't kill the parent menu
3. **Variable isolation** — modules can't accidentally overwrite menu state
4. **Environment contract** — explicit env vars are the clean interface; no leaked globals
5. **Exit code semantics** — subshell exit code is captured cleanly by the parent

The cost is that platform detection variables must be explicitly exported (not just set). This is a feature, not a bug — it makes the contract visible.

---

## Remote Module Fetching Architecture

### Cache Strategy

```
~/.cache/flu.sh/
├── modules/
│   ├── docker/
│   │   └── install.sh        # cached module script
│   ├── go/
│   │   └── install.sh
│   └── ...
└── meta/
    └── last_fetch            # timestamp of last fetch attempt
```

### Fetching Flow

```
exec_module("docker/install", "install")
    │
    ▼
resolve_path("docker/install")
    → local: ~/.cache/flu.sh/modules/docker/install.sh
    → remote: https://raw.githubusercontent.com/C-Fu/dev-fu/{branch}/modules/docker/install.sh
    │
    ▼
cache_valid?("docker/install")
    │
    ├── YES → use cached file
    │
    └── NO  → fetch_remote()
              │
              ├── curl -fsSL (preferred)
              ├── wget -qO-  (fallback)
              └── Error: "No network tool available"
              │
              ▼
         validate_module()  (sh -n syntax check)
              │
              ▼
         write to cache
              │
              ▼
         exec_module()  (sh <cached_file> <action> <args>)
```

### Cache Invalidation

- **No explicit versioning** — modules are fetched from the current git branch. If the user runs `flu.sh` from the `flu.sh` branch, they get the latest from that branch.
- **`FLU_NO_CACHE=1`** env var forces re-fetch (for development).
- **Age-based** — if cached file is older than 24 hours, re-fetch. Simple: `find "$cache" -mtime +1`.
- **No integrity check** — HTTPS provides transport security; trust GitHub as source. No checksum needed for this threat model.

### URL Construction

```sh
_FLU_BASE_URL="https://raw.githubusercontent.com/C-Fu/dev-fu"
_FLU_BRANCH="flu.sh"   # overridden by --branch flag or FLU_BRANCH env var

_module_url() {
    printf '%s/%s/modules/%s.sh' "$_FLU_BASE_URL" "$_FLU_BRANCH" "$1"
}
```

---

## Shell-Script Library Patterns

### Pattern Analysis for This Project

| Pattern | How It Works | Use For | Why |
|---------|-------------|---------|-----|
| **Sourced functions** | `source lib.sh` or `. lib.sh` | TUI engine, utilities | Shares terminal state, no subprocess overhead, functions access caller's variables |
| **Subshell execution** | `result=$(script.sh)` or `sh script.sh` | Module scripts | Isolation, clean exit codes, variable safety |
| **eval-based data** | `eval "var_$idx=value"` | Menu item storage | Only POSIX-portable way to have dynamically-indexed arrays |
| **Heredoc embedding** | `cmd <<'EOF' ... EOF` | Menu definitions, ASCII art | Zero-file deployment, all data in the script |
| **Positional args** | `widget "title" "prompt" "item1" "item2"` | Widget interface | Most portable calling convention |

### What NOT to Use

| Pattern | Why Avoid |
|---------|-----------|
| **Bash associative arrays** | Not POSIX — must work on dash/ash/busybox sh |
| **Process substitution `<()`** | Not POSIX |
| **`local` arrays** | Not POSIX (though most shells support `local` for scalars) |
| **`read -a`** | Bash-only |
| **Named pipes (FIFOs)** | Overkill, cleanup issues |
| **Temp files for IPC** | Cleanup fragility, permission issues in restricted environments |

### Function Organization Within Single File

Functions must be defined before they're called (shell's bottom-up execution). The file should be organized in dependency order:

```sh
#!/bin/sh
# flu.sh — Modular TUI Environment Setup Utility

# ═══════════════════════════════════════════
# Section 1: Utility Functions (no deps)
# ═══════════════════════════════════════════
die() { ... }
retry_network() { ... }

# ═══════════════════════════════════════════
# Section 2: Platform Detection (utility deps)
# ═══════════════════════════════════════════
detect_platform() { ... }
detect_distro() { ... }
pkg_install() { ... }

# ═══════════════════════════════════════════
# Section 3: Terminal Primitives (no deps)
# ═══════════════════════════════════════════
term_init() { ... }
term_restore() { ... }
read_key() { ... }
move_cursor() { ... }

# ═══════════════════════════════════════════
# Section 4: Drawing Primitives (term deps)
# ═══════════════════════════════════════════
draw_box() { ... }
draw_title() { ... }
truncate_text() { ... }

# ═══════════════════════════════════════════
# Section 5: Widgets (drawing deps)
# ═══════════════════════════════════════════
menu_single() { ... }
checklist() { ... }
inputbox() { ... }
yesno() { ... }

# ═══════════════════════════════════════════
# Section 6: Menu System (widget + data deps)
# ═══════════════════════════════════════════
_parse_menu_defs() { ... }
_menu_children() { ... }
_nav_push() { ... }
_nav_pop() { ... }

# ═══════════════════════════════════════════
# Section 7: Prompt System (widget deps)
# ═══════════════════════════════════════════
ask_choice() { ... }
ask_text() { ... }

# ═══════════════════════════════════════════
# Section 8: Module Execution (no widget deps)
# ═══════════════════════════════════════════
fetch_module() { ... }
exec_module() { ... }

# ═══════════════════════════════════════════
# Section 9: Built-in Actions (platform deps)
# ═══════════════════════════════════════════
status_check() { ... }
upgrade_all() { ... }

# ═══════════════════════════════════════════
# Section 10: Main Orchestrator
# ═══════════════════════════════════════════
run_cli_mode() { ... }
main_loop() { ... }

# ═══════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════
# TTY reattach, platform detect, parse args, enter main_loop
```

---

## Patterns to Follow

### Pattern 1: Widget Interface Contract

**What:** Every widget follows the same calling convention — takes config as positional args, writes result to stdout, returns exit code.

**When:** All interactive UI elements.

**Example:**
```sh
# Single-select menu
selected_tag=$(menu_single "Title" "Prompt" "tag1|Label 1" "tag2|Label 2" "tag3|Label 3")
rc=$?
if [ $rc -eq 0 ]; then
    printf 'You selected: %s\n' "$selected_tag"
elif [ $rc -eq 1 ]; then
    printf 'Cancelled\n'
fi

# Checklist (multi-select)
selected_tags=$(checklist "Title" "Prompt" "tag1|Label 1|on" "tag2|Label 2|off")
rc=$?

# Yes/No
yesno "Continue with install?"
rc=$?

# Input box
value=$(inputbox "Enter scope" "global")
rc=$?
```

**Rationale:** This is the gum/fzf model. It's composable, testable, and pipeline-friendly. Each widget is a pure function: input in, selection out.

### Pattern 2: Eval-Based Dynamic Arrays

**What:** Use `eval` to simulate arrays in POSIX sh when Bash arrays aren't available.

**When:** Menu item storage, selection tracking.

**Example:**
```sh
# Store
i=1
eval "item_tag_$i=docker"
eval "item_label_$i='Install Docker'"

# Retrieve
eval "tag=\$item_tag_$i"
eval "label=\$item_label_$i"
```

**Rationale:** This is the only POSIX-compatible way to have dynamically-indexed data. Already proven in checklist.sh (lines 221-237). Avoid for user-supplied data (security) — only use for trusted menu definitions.

### Pattern 3: Fallback Chain

**What:** Try the best option first, degrade gracefully.

**When:** Terminal capabilities, network tools, display features.

**Example:**
```sh
# Terminal size
rows=$(tput lines 2>/dev/null) || rows=${LINES:-24}
cols=$(tput cols 2>/dev/null) || cols=${COLUMNS:-80}

# Network fetch
_fetch_url() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$1"
    else
        printf 'No curl or wget available\n' >&2
        return 1
    fi
}

# TTY fallback
if [ ! -t 0 ] || [ "${TERM:-}" = "dumb" ]; then
    checklist_fallback "$@"  # numbered prompt
fi
```

**Rationale:** Maximum portability. Already used in checklist.sh (lines 204-208) and fu.sh TTY reattach (line 41-47).

### Pattern 4: Menu Stack Navigation

**What:** Maintain a stack of menu contexts for push/pop navigation.

**When:** Hierarchical submenu navigation.

**Example:**
```sh
_nav_stack=""     # colon-separated: "main:install:lang"
_nav_depth=0

_nav_push() {
    _nav_stack="${_nav_stack}${_nav_stack:+:}$1"
    _nav_depth=$((_nav_depth + 1))
}

_nav_pop() {
    if [ "$_nav_depth" -gt 0 ]; then
        _nav_stack=$(printf '%s' "$_nav_stack" | awk -F':' '{
            for(i=1;i<NF;i++) printf "%s%s", (i>1?":":""), $i
        }')
        _nav_depth=$((_nav_depth - 1))
    fi
}

_nav_current() {
    printf '%s' "$_nav_stack" | awk -F':' '{print $NF}'
}
```

**Rationale:** Simple string-based stack, no arrays needed. Colon-separated is safe because menu tags use alphanumeric + underscore only. Max depth is 3 (project constraint), so performance is irrelevant.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Bash-Only Features in Core Logic

**What:** Using associative arrays, `[[ ]]`, `read -a`, `${var,,}`, process substitution.
**Why bad:** Breaks on dash (Debian's /bin/sh), ash (Alpine), busybox sh (embedded/containers).
**Instead:** Use `[ ]` tests, `case` statements, eval-based storage, `awk` for text processing.

### Anti-Pattern 2: Modules That Depend on TUI State

**What:** A module calling `menu_single()` or `read_key()`.
**Why bad:** Modules run in subshells — they don't have access to the TUI engine's stty state, and they shouldn't. The TUI is flu.sh's concern.
**Instead:** All prompts happen in flu.sh before module execution. Collected values pass as arguments.

### Anti-Pattern 3: Fetching Modules at Menu Definition Time

**What:** Downloading all module scripts at startup.
**Why bad:** Defeats the on-demand design; slow startup; unnecessary network hits for modules the user never selects.
**Instead:** Fetch on first use, cache indefinitely. Only validate the module script exists (404 check) if desired.

### Anti-Pattern 4: Stateful Widget Instances

**What:** Creating a widget object that persists across renders.
**Why bad:** Shell functions don't have closures or objects. State must be managed externally via variables.
**Instead:** Pass all state as arguments on each render call. The widget is a pure function: (state + items) → render, (key + state) → new state.

### Anti-Pattern 5: Over-Abstracting the Menu Definition

**What:** Creating a recursive menu parser that supports arbitrary nesting depth.
**Why bad:** The project constraint is 3 levels max. Over-engineering adds complexity with no payoff.
**Instead:** Flat list with parent tags. Simple iteration for children. No recursion needed.

---

## Scalability Considerations

| Concern | At 10 menu items | At 50 menu items | At 100+ menu items |
|---------|------------------|------------------|---------------------|
| Parse time | Instant (<1ms) | Negligible (<5ms) | Still fast (<20ms) — awk on in-memory heredoc |
| Render time | Instant | Instant | Pagination handles display; eval access is O(1) per item |
| Memory | ~20 eval vars | ~100 eval vars | ~200 eval vars — shell handles this fine |
| Module fetch | 0 network hits (on-demand) | 0 network hits | 0 network hits |
| Cache disk | Minimal | ~50KB total | ~100KB total — negligible |

Shell scripts fundamentally don't scale to thousands of items because eval-based storage is slow at that scale. But for 50-100 menu items (which covers a comprehensive dev tool setup), this architecture is more than adequate.

---

## Suggested Build Order

The build order follows strict dependency chains. Each phase produces a testable artifact.

```
Phase 1: Terminal Primitives          ── no dependencies
│  term_init, term_restore, read_key, move_cursor, clear_screen
│  Test: key-echo demo
│
Phase 2: Drawing Primitives           ── depends on Phase 1
│  draw_box, draw_title, draw_separator, truncate_text
│  Test: render a box with a title
│
Phase 3: Single-Select Menu Widget    ── depends on Phase 2
│  menu_single(title, prompt, items...) → tag to stdout
│  Test: interactive single-choice menu
│
Phase 4: Additional Widgets           ── depends on Phase 2
│  checklist, yesno, inputbox, infobox
│  (checklist.sh already exists — adapt, don't rewrite)
│  Test: each widget standalone
│
Phase 5: Menu Definition Parser       ── no TUI dependency (parallel with 3-4)
│  _parse_menu_defs, _menu_children, _menu_lookup
│  Test: load definitions, query children of "main"
│
Phase 6: Module Fetcher + Exec        ── no TUI dependency (parallel with 3-5)
│  fetch_module, validate_module, exec_module
│  Test: fetch and execute a sample module
│
Phase 7: Navigation Controller        ── depends on Phase 3 + 5
│  Nav stack (push/pop), breadcrumb display
│  Test: navigate main → install → lang → back → back
│
Phase 8: Prompt System                ── depends on Phase 4
│  ask_choice, ask_text, ask_confirm
│  Test: collect scope=global and pass to module
│
Phase 9: Main Orchestrator            ── depends on ALL above
│  CLI parsing, main loop, error handling, result display
│  Test: full E2E flow — start → navigate → select → module → result
│
Phase 10: Polish & Edge Cases
│  Dumb terminal fallback, resize handling, signal cleanup
│  WSL/Termux/Alpine testing
│  Test: run in docker Alpine container
```

### Parallelization Opportunities

Phases 3/4, 5, and 6 can be developed in parallel — they have zero dependencies on each other. This is the critical path optimization:

```
   Phase 1 ──→ Phase 2 ──┬──→ Phase 3 ──→ Phase 7 ──→ Phase 9
                          ├──→ Phase 4 ──→ Phase 8 ──↗
                          └──→ Phase 5 ──→ Phase 7 ──↗
   Phase 6 (independent) ──────────────────────────→ Phase 9
```

### Critical Path

Phase 1 → Phase 2 → Phase 3 → Phase 7 → Phase 9

The single-select menu widget (Phase 3) is the critical gate. Everything interactive depends on it. Get it working early and the rest unblocks.

---

## How Existing Tools Structure Their Internals

### lxdialog (Linux kernel menuconfig)

**Architecture:** Shared primitives + separate widget modules.

- `dialog.h` — shared types (`dialog_color`, `dialog_item`, `dialog_info`), function prototypes, constants
- `util.c` — drawing primitives (`draw_box`, `draw_shadow`, `attr_clear`, `print_autowrap`)
- `menubox.c`, `checklist.c`, `inputbox.c`, `yesno.c`, `textbox.c` — widget implementations
- Each widget: `dialog_<type>(title, prompt, height, width, ...) → int`
- Item list: global linked list (`item_head`, `item_cur`, `item_nil`)

**Lesson for flu.sh:** The layered approach (shared primitives → widget types) is the right model. But flu.sh uses eval-based storage instead of linked lists because POSIX sh has no structs.

### gum (Charmbracelet)

**Architecture:** Command-per-widget, each is a standalone CLI subcommand.

- Directory structure: `choose/`, `confirm/`, `input/`, `filter/`, etc.
- Each widget is a Go module with its own `options.go` and command handler
- All widgets use Bubble Tea ( Elm Architecture) internally
- Interface: `stdin → process → stdout + exit code`
- Customization: flags + `GUM_<CMD>_*` environment variables

**Lesson for flu.sh:** The stdin→stdout+exit-code model is ideal. Each widget should be a callable function that takes config as args and returns result on stdout. The "command-per-widget" maps to "function-per-widget" in shell.

### fzf

**Architecture:** Single binary, stdin-list → interactive filter → stdout selection.

- Core loop: read items → render → handle key events → filter → output
- Fully pipeline-friendly: `echo items | fzf > selection`
- Customization: `--flag` options and `FZF_*` environment variables

**Lesson for flu.sh:** Pipeline composability is powerful. Widgets should work both as interactive TUI and as fallback numbered prompts (already in checklist.sh).

### checklist.sh (existing codebase)

**Architecture:** Single POSIX function + terminal helpers.

- Terminal primitives: `term_init()`, `term_restore()`, `read_key()`, `move_cursor()`
- Drawing: `_draw_box()`, `truncate_label()`
- Widget: `checklist(title, prompt, items...)` → selected tags on stdout
- Fallback: `checklist_fallback()` for dumb terminals
- Storage: `eval "item_tag_$idx=..."` pattern (lines 221-237)
- Key handling: dd-based raw reads, escape sequence parsing (lines 89-96)

**Lesson for flu.sh:** This is the foundation. Extract its primitives into the TUI engine layer, generalize `_draw_box` into a richer drawing API, and build new widgets using the same patterns. Don't rewrite — adapt and extend.

---

## Sources

- **lxdialog/dialog.h** — Linux kernel source (torvalds/linux/scripts/kconfig/lxdialog/dialog.h). HIGH confidence — canonical source for the widget-primitive pattern.
- **lxdialog/menubox.c** — Linux kernel source. HIGH confidence — shows menu widget implementation with scroll state, key handling, item rendering.
- **gum** — github.com/charmbracelet/gum. HIGH confidence — command-per-widget architecture, pipeline philosophy.
- **fzf** — github.com/junegunn/fzf. HIGH confidence — stdin/stdout pipeline model.
- **checklist.sh** — existing codebase (lines 1-596). HIGH confidence — proven POSIX patterns, already working in the project.
- **fu.sh** — existing codebase (lines 1-2629). HIGH confidence — parallel array dispatch pattern, menu structure, platform detection.
- **codebase/ARCHITECTURE.md** — existing analysis. HIGH confidence — comprehensive documentation of current monolithic architecture.
