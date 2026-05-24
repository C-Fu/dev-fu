# Coding Conventions

**Analysis Date:** 2026-05-23

## Naming Patterns

**Files:**
- Primary script: lowercase with `.sh` extension — `fu.sh`, `menu.sh`, `checklist.sh`
- PowerShell variant: lowercase with `.ps1` extension — `fu.ps1`
- Descriptive names with underscores separating words: `fancy_blue.sh`, `menuWSL.sh`

**Functions (Bash — `fu.sh`):**
- `snake_case` for all functions: `install_docker()`, `remove_docker()`, `status_check()`, `detect_platform()`
- Install/remove pairs follow `install_<tool>()` / `remove_<tool>()` naming
- Private/internal helpers prefixed with `_`: `_maybe_sudo()`, `_is_musl()`, `_reset_prompt()`, `_write_prompt_purple()`
- Status-check-compare sub-functions prefixed with `_scc_`: `_scc_gh()`, `_scc_local()`, `_scc_ver()`, `_scc_row()`
- `die()` used as the fatal-error function (not `error` or `fatal`)

**Functions (Bash — `menu.sh`, `checklist.sh`, `menuWSL.sh`):**
- `snake_case` for all functions: `checklist()`, `checklist_fallback()`, `term_init()`, `term_restore()`
- Internal helpers prefixed with `_`: `_term_saved_stty`, `_draw_box()`

**Functions (PowerShell — `fu.ps1`):**
- `PascalCase` with verb-noun convention: `Install-Docker`, `Remove-Docker`, `Get-StatusCheck`, `Set-GitHubToken`
- Standard PowerShell verb-noun naming: `Get-`, `Set-`, `Install-`, `Remove-`, `Show-`, `Write-`, `Reset-`

**Variables:**
- `UPPER_SNAKE_CASE` for constants and global config: `RED`, `GREEN`, `NC`, `BOX_TL`, `EMOJI_DOCKER`, `BATCH_MODE`
- `lower_snake_case` for function-local variables: `local rc_file`, `local confirm`, `local pkg_manager`
- Array variables: `UPPER_SNAKE_CASE` — `MENU_LABELS`, `MENU_EMOJIS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`
- PowerShell variables: `$PascalCase` — `$DETECTED_OS`, `$DETECTED_ARCH`, `$Script:BATCH_MODE`

## Code Style

**Formatting:**
- No automated formatter (shellcheck/shfmt not configured)
- Indentation: 4 spaces in `fu.sh` and PowerShell; inconsistent (mix of tabs and spaces) in `menu.sh`, `checklist.sh`, `menuWSL.sh`
- Line length: generally kept under 120 chars; some curl/pipeline lines exceed this

**Linting:**
- No linter configuration present (no `.shellcheckrc`, no `.shfmt`, no `.editorconfig`)
- shellcheck and shfmt are not installed in the dev environment

**Shebangs:**
- `fu.sh`: `#!/usr/bin/env bash` (requires Bash 4+ for associative arrays, `[[ ]]`, `${!array[@]}`)
- `menu.sh`, `menuWSL.sh`, `checklist.sh`: `#!/usr/bin/env sh` (POSIX-compatible)
- `fancy_blue.sh`: `#!/bin/sh`
- `web.sh`: `#!/bin/sh` (embeds Python inline)
- `fu.ps1`: No shebang (PowerShell file)

## Import Organization

**Order:**
1. Shebang line
2. Header comment block (title, description, compatibility, license)
3. Color/style constants (`RED`, `GREEN`, `NC`, etc.)
4. Box-drawing constants
5. Emoji constants
6. Menu arrays (`MENU_LABELS`, `MENU_EMOJIS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`, `MENU_SINGLE_SELECT`)
7. Helper/utility functions (`detect_rc_file`, `die`, `retry_network`)
8. Platform detection functions and global variable assignment
9. Package manager abstraction layer (`pkg_update`, `pkg_install`, `pkg_remove`)
10. Feature functions grouped by menu option (install/remove pairs)
11. Menu display and input parsing
12. CLI mode handler
13. Main interactive loop

**Sourcing:**
- `fu.sh` sources `$HOME/.nvm/nvm.sh` on demand (not at top level)
- `fu.sh` sources generated prompt files (`~/.fancy-prompt.sh`) at runtime
- `checklist.sh` is designed to be sourced: `source checklist.sh` to get the `checklist()` function
- No `source` or `.` imports between project files (each `.sh` is self-contained)

## Error Handling

**Patterns:**
- Fatal errors use `die()` which prints to stderr and exits:
  ```bash
  die() {
      echo -e "${RED}⚠ Error: $1${NC}" >&2
      exit ${2:-1}
  }
  ```
- Non-fatal errors print colored messages and `return 1`:
  ```bash
  pkg_install ... || { echo -e "${RED}  ✗ Docker install failed${NC}"; return 1; }
  ```
- Network operations use `retry_network` with configurable attempts and delay:
  ```bash
  retry_network 3 5 "curl -fsSL https://..."
  ```
- Graceful degradation: `|| true` appended to commands where failure is acceptable:
  ```bash
  rm -f /tmp/get-docker.sh  # cleanup — failure OK
  _maybe_sudo systemctl start avahi-daemon || { echo -e "${YELLOW}  ⚠ Could not start avahi-daemon${NC}"; }
  ```
- `2>/dev/null` used liberally to suppress expected stderr from version checks and `command -v`
- PowerShell uses `try/catch` blocks and `$ErrorActionPreference = 'SilentlyContinue'`:
  ```powershell
  try {
      $resp = Invoke-RestMethod -Uri "https://api.github.com/repos/..." -Headers $headers -ErrorAction Stop
  } catch {}
  ```

**Exit codes (from README):**
- 0 — Success
- 1 — Error
- 2 — Invalid option

## Logging

**Framework:** Direct `echo -e` with ANSI color codes — no logging library

**Patterns:**
- Progress messages use `CYAN`: `${CYAN}  Installing Docker...${NC}`
- Success messages use `GREEN` with check emoji: `${GREEN}  ✓ Docker installed${NC}`
- Warnings use `YELLOW`/`BYELLOW`: `${BYELLOW}  → This will install: Docker${NC}`
- Errors use `RED` with cross emoji: `${RED}  ✗ Docker install failed${NC}`
- Dim/secondary text uses `DIM` style: `${DIM}  Cancelled.${NC}`
- Status output uses emoji prefixes for visual categorization

## Comments

**When to Comment:**
- Every major section has a Unicode box-drawing separator with emoji and option number:
  ```bash
  # ──────────────
  # 🐳 Option 5: Install Docker
  # ──────────────
  ```
- File headers include description, compatibility, and license
- Inline comments explain non-obvious logic (e.g., Alpine musl incompatibility, Docker Desktop detection)
- Checklist files have extensive usage documentation in the header

**Function docs:**
- No formal doc strings (no JSDoc/shdoc equivalent)
- Function names are self-documenting: `install_docker()`, `detect_platform()`

## Function Design

**Size:** Functions range from 10 lines (`detect_rc_file`) to ~150 lines (`install_opencode_gsd`). Most install/remove functions are 20–50 lines.

**Parameters:**
- Positional parameters with `local` naming at the top:
  ```bash
  install_docker() {
      # no params — uses global state
  }
  retry_network() {
      local max_attempts=${1:-3}
      local delay=${2:-2}
      shift 2
      local cmd="$@"
  }
  ```
- Default values via `${1:-default}` syntax
- `$@` used for forwarding remaining args to `eval`

**Return Values:**
- `return 0` for success, `return 1` for failure
- No explicit `return` at end of successful functions (implicit 0 from last command)
- Early return pattern for "already installed" checks:
  ```bash
  if command -v docker >/dev/null 2>&1; then
      echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Docker already installed"
      return 0
  fi
  ```

## Module Design

**Exports:**
- All functions are global — no namespacing or module pattern
- Internal functions distinguished by `_` prefix only

**Barrel Files:**
- Not used. Each `.sh` file is fully self-contained
- `checklist.sh` is designed to be sourced from other scripts, exposing the `checklist()` function
- `menu.sh` and `menuWSL.sh` are standalone executables with embedded demo mode

## Global State

**Module-level globals in `fu.sh`:**
- `DETECTED_OS`, `DETECTED_DISTRO`, `DETECTED_WSL`, `DETECTED_ENV` — set once at startup
- `BATCH_MODE` — toggled between `0` and `1` for interactive vs non-interactive operation
- Color constants: `RED`, `GREEN`, `YELLOW`, etc.
- Menu arrays: `MENU_LABELS`, `MENU_EMOJIS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`, `MENU_SINGLE_SELECT`
- Box-drawing chars: `BOX_TL`, `BOX_TR`, etc.

**Parse state (set by `parse_input`):**
- `PARSE_INSTALL_IDX`, `PARSE_REMOVE_IDX` — bash arrays used to communicate parsed results

## User Interaction Pattern

**Confirmation pattern (interactive mode):**
```bash
echo -e "${BYELLOW}  → This will install: Docker${NC}"
if [[ "$BATCH_MODE" != "1" ]]; then
    read -rp "  Proceed? (y/n): " confirm
    [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
fi
```

- Every destructive operation asks for confirmation unless `BATCH_MODE=1`
- `BATCH_MODE` is set to `1` when CLI args are passed or when multi-select confirmation is accepted
- Pattern must be preserved in all new install/remove functions

---

*Convention analysis: 2026-05-23*
