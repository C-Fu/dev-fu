<!-- refreshed: 2026-05-22 -->
# Architecture

**Analysis Date:** 2026-05-22

## System Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                        User Interface                           │
├────────────────────┬───────────────────────┬────────────────────┤
│  Interactive Menu  │   CLI Mode (args)     │  Web Server        │
│  (fu.sh main loop) │  (fu.sh with args)    │  (web.sh)          │
│  `fu.sh:2600-2629` │  `fu.sh:2573-2594`    │  `web.sh:1-85`     │
└────────┬───────────┴──────────┬────────────┴────────────────────┘
         │                      │
         ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Menu Parsing & Dispatch                      │
│  parse_input()          show_confirmation_screen()               │
│  `fu.sh:2415-2517`      `fu.sh:2520-2567`                       │
├─────────────────────────────────────────────────────────────────┤
│  Parallel PowerShell port: fu.ps1 (1972 lines, same structure)  │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌──────────────────┐
│  Installers     │ │  Status/Compare │ │  Remove Functions│
│  (18 options)   │ │  (diagnostics)  │ │  (per-option)    │
│  `fu.sh:485-    │ │  `fu.sh:1214-   │ │  paired with     │
│   2362`         │ │   1529`         │ │  each installer  │
└────────┬────────┘ └────────┬────────┘ └────────┬─────────┘
         │                   │                    │
         ▼                   ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Platform Abstraction Layer                     │
│  detect_platform()  detect_distro()  detect_wsl()               │
│  get_pkg_manager()  detect_environment()                        │
│  pkg_install()  pkg_remove()  pkg_update()  pkg_purge()        │
│  `fu.sh:160-321`                                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌──────────────────┐
│  System Package │ │  Official       │ │  npm Registry    │
│  Managers       │ │  Installers     │ │  (global pkgs)   │
│  apt/apk/dnf/   │ │  get.docker.com │ │  yarn, opencode, │
│  pacman/zypper/ │ │  sh.rustup.rs   │ │  openchamber,    │
│  brew/winget/   │ │  bun.sh/install │ │  gsd-opencode    │
│  choco          │ │  nvm/install.sh │ │                  │
└─────────────────┘ └─────────────────┘ └──────────────────┘
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│                   External Services & APIs                       │
│  GitHub API · npm Registry · go.dev · nodejs.org · pypi.org    │
│  ipify · tailscale.com · endoflife.date · static.rust-lang.org │
└─────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `fu.sh` | Primary Bash entry point — all Unix/macOS logic | `fu.sh` |
| `fu.ps1` | PowerShell equivalent — Windows logic | `fu.ps1` |
| `checklist.sh` | Standalone POSIX multi-select checklist widget | `checklist.sh` |
| `menu.sh` | Earlier version of POSIX checklist (with embedded example) | `menu.sh` |
| `menuWSL.sh` | WSL-specific variant of POSIX checklist | `menuWSL.sh` |
| `fancy_blue.sh` | Standalone "Shades of Blue" prompt theme | `fancy_blue.sh` |
| `web.sh` | Development HTTP server for LAN testing | `web.sh` |
| `README.md` | English documentation | `README.md` |
| `README.ms-MY.md` | Bahasa Melayu documentation | `README.ms-MY.md` |

## Pattern Overview

**Overall:** Monolithic script with table-driven dispatch (install/remove function arrays).

**Key Characteristics:**
- **Zero-dependency execution** — No interpreter beyond Bash 4+ or PowerShell 5.1+.
- **Platform polymorphism** — Single codebase adapts at runtime via `detect_*()` functions. Package manager, OS, architecture, and environment are detected once at startup.
- **Atomic install/remove pairs** — Every install option has a corresponding remove function referenced in `MENU_REMOVE_FN`.
- **Table-driven menu** — `MENU_LABELS`, `MENU_EMOJIS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`, `MENU_SINGLE_SELECT` arrays define the entire menu system. Adding a new option requires appending to all five arrays and writing the install/remove functions.

## Layers

**Presentation Layer:**
- Purpose: User interaction (menu display, prompts, confirmation screens).
- Location: `fu.sh:2370-2567` (`show_menu`, `parse_input`, `show_confirmation_screen`, main loop at `fu.sh:2600-2629`).
- Contains: ASCII art banner, numbered menu, input parsing, batch confirmation box.
- Depends on: Install/remove functions.
- Used by: End user (interactive) or CLI arguments (non-interactive).

**Business Logic Layer:**
- Purpose: Tool installation, removal, status checking, version comparison, upgrading.
- Location: `fu.sh:485-2362` (all `install_*`, `remove_*`, `status_check`, `status_check_compare`, `upgrade_all` functions).
- Contains: 18 install functions, 14 remove functions, 2 diagnostic functions, 1 upgrade function.
- Depends on: Platform abstraction layer, external APIs/installers.
- Used by: Presentation layer dispatch.

**Platform Abstraction Layer:**
- Purpose: Abstract OS, package manager, and environment differences.
- Location: `fu.sh:160-321`.
- Contains: `detect_platform()`, `detect_distro()`, `detect_wsl()`, `detect_environment()`, `get_pkg_manager()`, `pkg_update()`, `pkg_install()`, `pkg_remove()`, `pkg_purge()`, `pkg_autoremove()`, `_maybe_sudo()`, `ensure_sudo()`.
- Depends on: System utilities (`uname`, `/etc/os-release`, `command -v`).
- Used by: All install/remove/upgrade functions.

**Utility Layer:**
- Purpose: Shared helpers (colors, retry logic, RC file management, error handling).
- Location: `fu.sh:1-159`.
- Contains: Color palette (`RED`, `GREEN`, etc.), box drawing characters, emoji constants, `detect_rc_file()`, `append_rc_if_missing()`, `die()`, `retry_network()`.
- Depends on: Nothing external.
- Used by: All other layers.

## Data Flow

### Primary Request Path (Interactive)

1. Script starts — TTY check reattaches stdin (`fu.sh:41-47`).
2. Platform detection runs — sets `DETECTED_OS`, `DETECTED_DISTRO`, `DETECTED_WSL`, `DETECTED_ENV`, `get_pkg_manager` (`fu.sh:191-207`).
3. CLI arguments checked — if present, runs `run_cli_mode()` and exits (`fu.sh:2592-2595`).
4. Main loop begins — clears screen, calls `preflight_status()` to display system info (`fu.sh:2600-2604`).
5. `show_menu()` displays 18 options (`fu.sh:2603`).
6. User input read (`fu.sh:2604`).
7. `parse_input()` tokenizes, validates, deduplicates, checks for conflicts (`fu.sh:2614`).
8. `show_confirmation_screen()` for multi-select (single select skips) (`fu.sh:2615`).
9. `BATCH_MODE=1` set — individual confirmations suppressed (`fu.sh:2616`).
10. Install functions called via `${MENU_INSTALL_FN[$idx]}` dispatch (`fu.sh:2617-2619`).
11. Remove functions called via `${MENU_REMOVE_FN[$idx]}` dispatch (`fu.sh:2620-2622`).
12. Pause for keypress, loop back to step 4 (`fu.sh:2628`).

### CLI Mode Flow

1. Arguments passed: `bash fu.sh 5 11 -9` (`fu.sh:2592`).
2. `BATCH_MODE=1` set (`fu.sh:2593`).
3. `run_cli_mode()` called (`fu.sh:2594`).
4. If `"u"` — runs `upgrade_all()` and exits (`fu.sh:2576-2579`).
5. Otherwise — `parse_input()` validates, then dispatches install/remove functions (`fu.sh:2581-2588`).
6. Exit (`fu.sh:2589`).

### Version Comparison Flow (Option 2)

1. `status_check_compare()` calls `_scc_gh()` for each tool's GitHub repo (`fu.sh:1477-1524`).
2. `_scc_gh()` fetches latest release tag via GitHub API, with fallbacks to package registries (npm, PyPI, go.dev, etc.) (`fu.sh:1327-1408`).
3. `_scc_local()` runs `tool --version` with timeout for local version (`fu.sh:1411-1433`).
4. `_scc_ver()` extracts semver from output (`fu.sh:1435-1437`).
5. `_scc_row()` compares and prints with color-coded status (`fu.sh:1439-1472`).

**State Management:**
- All state is local to the running process. No persistent state files (except `~/.config/dev-fu/github-token`).
- `DETECTED_*` globals set once at startup and read throughout.
- `BATCH_MODE` toggles confirmation prompts.
- `PARSE_INSTALL_IDX` / `PARSE_REMOVE_IDX` are populated by `parse_input()` and consumed by the main loop.

## Key Abstractions

**Package Manager Polymorphism:**
- Purpose: Abstract 8 different package managers behind a uniform interface.
- Examples: `fu.sh:245-321` (`pkg_install`, `pkg_remove`, `pkg_update`, `pkg_purge`, `pkg_autoremove`).
- Pattern: Case-switch dispatch on `$(get_pkg_manager)` result.

**Install/Remove Function Pairs:**
- Purpose: Every installable tool has a matching uninstaller.
- Examples: `install_docker()` / `remove_docker()`, `install_go()` / `remove_go()`.
- Pattern: Parallel arrays `MENU_INSTALL_FN` and `MENU_REMOVE_FN` indexed by menu position.

**Idempotent Install Guards:**
- Purpose: Each installer checks if the tool is already installed before proceeding.
- Examples: `command -v docker >/dev/null 2>&1` at top of every `install_*()` function.
- Pattern: Early return with success message if already present.

**Retry Network:**
- Purpose: Handle transient network failures during downloads.
- Examples: `fu.sh:139-155`.
- Pattern: `retry_network 3 5 "command"` — retry up to 3 times with 2s delay.

## Entry Points

**`fu.sh` (Interactive):**
- Location: `fu.sh:2600-2629`
- Triggers: `bash fu.sh` (no arguments)
- Responsibilities: Display system info, show menu, parse selection, dispatch operations, loop.

**`fu.sh` (CLI Mode):**
- Location: `fu.sh:2592-2594` → `fu.sh:2573-2590`
- Triggers: `bash fu.sh [options...]`
- Responsibilities: Parse CLI args, dispatch operations, exit.

**`fu.ps1` (Windows):**
- Location: `fu.ps1` (mirrors fu.sh structure with PowerShell syntax)
- Triggers: `.\fu.ps1` or `irm ... | Invoke-Expression`
- Responsibilities: Same as fu.sh, adapted for Windows.

**`web.sh` (Development Server):**
- Location: `web.sh:1-85`
- Triggers: `sh web.sh`
- Responsibilities: Serve `fu.sh` over HTTP for LAN testing.

**`checklist.sh` (Standalone Widget):**
- Location: `checklist.sh:181-373`
- Triggers: `./checklist.sh --demo` or `source checklist.sh` then call `checklist()`.
- Responsibilities: Terminal-based multi-select checklist UI widget.

## Architectural Constraints

- **Single-threaded execution:** Bash scripts are inherently sequential. No concurrency (except `web.sh` uses Python threading).
- **Global state:** `DETECTED_OS`, `DETECTED_DISTRO`, `DETECTED_WSL`, `DETECTED_ENV`, `BATCH_MODE`, `_GITHUB_TOKEN_FILE` are module-level globals set once and read everywhere.
- **No circular dependencies:** Functions are defined bottom-up; helpers first, then installers, then menu, then main loop.
- **Platform branching:** Many functions contain inline `if _is_musl; then` or `case "$(get_pkg_manager)" in` branches. This is intentional — each platform path is explicitly handled.
- **Monolithic file:** `fu.sh` is a single 2629-line file with no imports or external script sourcing (except `~/.nvm/nvm.sh` for Node version detection).

## Anti-Patterns

### Duplicated Fancy Prompt Templates

**What happens:** The purple-pink prompt template (`_write_prompt_purple`, `fu.sh:689-982`) and blue prompt template (`_write_prompt_blue`, `fu.sh:984-1134`) are 290+ lines of heredoc content embedded directly in `fu.sh`. A standalone copy also exists as `fancy_blue.sh` (348 lines).
**Why it's wrong:** Three copies of similar prompt logic. Changes to one must be replicated.
**Do this instead:** Extract prompt templates to separate files (`prompts/purple.sh`, `prompts/blue.sh`) and `source` or `cat` them at runtime.

### Monolithic Script Size

**What happens:** `fu.sh` is 2629 lines in a single file. `fu.ps1` is 1971 lines.
**Why it's wrong:** Difficult to navigate and maintain. Each new tool install adds ~60-100 lines.
**Do this instead:** Consider modularizing installers into separate files (`installers/docker.sh`, `installers/go.sh`) sourced by the main script. This would not break the "single-file download" model — a build step could concatenate for distribution.

### Checklist Code Duplication

**What happens:** `checklist.sh`, `menu.sh`, and `menuWSL.sh` are near-identical copies of the same POSIX checklist widget (~596, ~654, and ~574 lines respectively).
**Why it's wrong:** Bug fixes or feature additions must be applied to three files.
**Do this instead:** Keep `checklist.sh` as the canonical source. Delete or redirect `menu.sh` and `menuWSL.sh` to source `checklist.sh`.

## Error Handling

**Strategy:** Fail-loud with color-coded messages. Each install function returns non-zero on failure.

**Patterns:**
- `die()` — Print red error message and exit with code (default 1). Used for fatal errors only (`fu.sh:131-134`).
- Inline error echo — Most functions use `echo -e "${RED}  ✗ ...${NC}"` followed by `return 1`.
- `|| { echo error; return 1; }` — Chained error handling after each install step.
- `|| true` — Expected failures (e.g., removing a package that might not exist).
- `retry_network()` — Network operations wrapped with 3-attempt retry (`fu.sh:139-155`).

## Cross-Cutting Concerns

**Logging:** Direct `echo -e` to stdout/stderr with ANSI colors. No log levels, no file logging.
**Validation:** Input parsing in `parse_input()` validates range (1-18), deduplication, install/remove conflicts, and single-select constraints (`fu.sh:2415-2517`).
**Authentication:** GitHub PAT stored in `~/.config/dev-fu/github-token`, used via `-H 'Authorization: token ...'` header in curl calls.

---

*Architecture analysis: 2026-05-22*
