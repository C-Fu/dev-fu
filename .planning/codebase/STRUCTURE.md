# Codebase Structure

**Analysis Date:** 2026-05-22

## Directory Layout

```
dev-fu/
├── .git/                        # Git repository data
├── .planning/                   # GSD planning documents (generated)
│   └── codebase/                # Codebase mapping output
├── fu.sh                        # Main Bash script (Unix/macOS/WSL) — 2629 lines
├── fu.ps1                       # PowerShell equivalent (Windows) — 1971 lines
├── checklist.sh                 # Standalone POSIX multi-select checklist widget — 596 lines
├── menu.sh                      # Earlier variant of POSIX checklist — 654 lines
├── menuWSL.sh                   # WSL-specific variant of POSIX checklist — 574 lines
├── fancy_blue.sh                # Standalone "Shades of Blue" prompt theme — 348 lines
├── web.sh                       # Development HTTP server (Python 3 embedded) — 85 lines
├── README.md                    # English documentation — 339 lines
├── README.ms-MY.md              # Bahasa Melayu documentation — 339 lines
├── npm_error.log                # Historical debug log (not part of normal operation)
└── error at line 64 expected bracket.txt  # Historical error note (not part of normal operation)
```

## Directory Purposes

**Root (`/`):**
- Purpose: Flat file structure — all source files at root level. No subdirectories for source code.
- Contains: Shell scripts, PowerShell script, Markdown documentation, historical artifacts.
- Key files: `fu.sh` (primary), `fu.ps1` (Windows port), `README.md` (docs).

**`.planning/`:**
- Purpose: GSD (Get Stuff Done) planning artifacts.
- Contains: `codebase/` subdirectory with analysis documents (this file and siblings).
- Generated: Yes (by `/gsd-map-codebase`).
- Committed: Yes (part of repo history).

## Key File Locations

**Entry Points:**
- `fu.sh`: Main interactive menu system for Unix/macOS/WSL. Executable (`chmod +x`). Line 2600-2629 is the interactive main loop; line 2573-2590 is CLI mode entry.
- `fu.ps1`: Main interactive menu system for Windows. Line 1972 is the interactive main loop.
- `web.sh`: Development server — run with `sh web.sh`. Not executable-focused; serves `fu.sh` over HTTP.
- `checklist.sh`: Standalone checklist widget — run with `./checklist.sh --demo` or sourced for embedding.

**Configuration:**
- No project configuration files (no `.eslintrc`, `tsconfig.json`, `package.json`, etc.).
- Runtime configuration is created dynamically:
  - `~/.config/dev-fu/github-token` — GitHub PAT (option 4).
  - `~/.fancy-prompt.sh` — Purple-pink prompt (option 6).
  - `~/.fancy-prompt-blue.sh` — Blue prompt (option 7).
  - `~/.bashrc` / `~/.zshrc` — Modified to source prompt scripts and add PATH entries.

**Core Logic (Bash):**
- `fu.sh:1-159` — Utility layer (colors, box drawing, emojis, helpers, retry logic).
- `fu.sh:160-321` — Platform abstraction (detection, package manager wrappers).
- `fu.sh:352-426` — System status display (`preflight_status`), uv installer.
- `fu.sh:431-480` — GitHub token management.
- `fu.sh:485-551` — Docker install/remove.
- `fu.sh:555-675` — Hostname discovery (avahi/systemd-resolved) install/remove.
- `fu.sh:680-1209` — Fancy prompt templates and install/remove (two themes).
- `fu.sh:1214-1318` — Status check (option 1).
- `fu.sh:1320-1529` — Version comparison (option 2).
- `fu.sh:1534-1570` — Go install/remove.
- `fu.sh:1572-1605` — Rust install/remove.
- `fu.sh:1607-1668` — Python/pip/uv/pipx install/remove.
- `fu.sh:1674-1751` — NVM/Node install/remove.
- `fu.sh:1753-1786` — Bun install/remove.
- `fu.sh:1788-1821` — Yarn install/remove.
- `fu.sh:1823-1860` — Mouse reporting toggle.
- `fu.sh:1865-2012` — Upgrade all (option 3).
- `fu.sh:2017-2074` — Tailscale install/remove.
- `fu.sh:2079-2260` — OpenCode + GSD + OpenChamber install/remove.
- `fu.sh:2265-2362` — PHP + Laravel install/remove.
- `fu.sh:2370-2413` — Menu display (`show_menu`).
- `fu.sh:2415-2517` — Input parsing (`parse_input`).
- `fu.sh:2520-2567` — Confirmation screen (`show_confirmation_screen`).
- `fu.sh:2573-2594` — CLI mode dispatch.
- `fu.sh:2600-2629` — Interactive main loop.

**Core Logic (PowerShell):**
- `fu.ps1` mirrors `fu.sh` structure using PowerShell conventions:
  - `Verb-Noun` function naming (e.g., `Install-Docker`, `Remove-Go`).
  - `Get-Command` instead of `command -v`.
  - `Invoke-RestMethod` instead of `curl`.
  - `Write-Host` instead of `echo -e`.
  - `$Script:BATCH_MODE` instead of `BATCH_MODE`.

**Supporting Files:**
- `checklist.sh:1-59` — POSIX dispatcher + terminal helpers.
- `checklist.sh:60-178` — Fallback numbered prompt.
- `checklist.sh:181-373` — Main POSIX checklist function (TUI).
- `checklist.sh:375-397` — Demo mode and direct invocation.
- `checklist.sh:399-596` — Embedded Fish shell implementation.

**Documentation:**
- `README.md` — Full English documentation with screenshots, platform matrix, usage guide.
- `README.ms-MY.md` — Bahasa Melayu translation.

**Historical Artifacts:**
- `npm_error.log` — 1569-line npm error log from a past debugging session. Not part of normal operation.
- `error at line 64 expected bracket.txt` — 574-line error report. Not part of normal operation.
- `menu.sh`, `menuWSL.sh` — Earlier iterations of the checklist widget. Superseded by `checklist.sh`.

## Naming Conventions

**Files:**
- `fu.sh` / `fu.ps1`: Main scripts named after the project ("dev-fu"). Short, memorable.
- `checklist.sh`: Descriptive name for the standalone widget.
- `web.sh`: Descriptive name for the development server.
- `menu.sh`, `menuWSL.sh`: Legacy naming from earlier development iterations.
- `fancy_blue.sh`: Descriptive name for the prompt theme.
- `README.md`: Standard documentation file.
- `README.ms-MY.md`: Locale-tagged documentation (`ms-MY` = Bahasa Melayu).

**Functions (Bash):**
- Install functions: `install_{tool}` (e.g., `install_docker`, `install_go`, `install_python`).
- Remove functions: `remove_{tool}` (e.g., `remove_docker`, `remove_go`, `remove_python`).
- Status functions: `status_check`, `status_check_compare`, `upgrade_all`.
- Helpers: `detect_{platform/distro/wsl/environment}`, `pkg_{install/remove/update/purge}`, `_maybe_sudo`.
- Internal helpers: Prefixed with `_` (e.g., `_is_musl`, `_scc_gh`, `_scc_local`, `_write_prompt_purple`).

**Functions (PowerShell):**
- `Verb-Noun` convention: `Install-Docker`, `Remove-Go`, `Get-StatusCheck`, `Upgrade-All`.

**Variables:**
- Constants: `UPPER_CASE` (e.g., `RED`, `GREEN`, `BOX_TL`, `DETECTED_OS`).
- Function-local: `local` keyword used (e.g., `local pm`, `local go_pkg`).
- Globals: `DETECTED_OS`, `DETECTED_DISTRO`, `DETECTED_WSL`, `DETECTED_ENV`, `BATCH_MODE`.

## Where to Add New Code

**New Tool Installer (e.g., "Install Terraform"):**
1. Add entry to `MENU_LABELS` array at `fu.sh:91-110`.
2. Add emoji to `MENU_EMOJIS` array at `fu.sh:111`.
3. Add install function name to `MENU_INSTALL_FN` at `fu.sh:112`.
4. Add remove function name to `MENU_REMOVE_FN` at `fu.sh:113` (or `""` if no remove).
5. Add single-select flag to `MENU_SINGLE_SELECT` at `fu.sh:114` (`0` = multi, `1` = solo).
6. Write `install_terraform()` function following the pattern:
   ```bash
   install_terraform() {
       echo -e "${CYAN}${EMOJI}  ${BOLD}Install Terraform${NC}"
       echo -e "${DIM}   Description${NC}"
       echo
       if command -v terraform >/dev/null 2>&1; then
           echo -e "  ${GREEN}${EMOJI_CHECK}${NC} Terraform already installed: $(terraform version)"
           return 0
       fi
       echo -e "${BYELLOW}  → This will install: Terraform${NC}"
       if [[ "$BATCH_MODE" != "1" ]]; then
           read -rp "  Proceed? (y/n): " confirm
           [[ $confirm != [yY] ]] && echo -e "${DIM}  Cancelled.${NC}" && return
       fi
       # ... install logic ...
       echo -e "${GREEN}  ✓ Terraform installed successfully${NC}"
   }
   ```
7. Write matching `remove_terraform()` function.
8. Add version check to `status_check()` at `fu.sh:1214-1318`.
9. Add version comparison row to `status_check_compare()` at `fu.sh:1477-1524`.
10. Add upgrade path to `upgrade_all()` at `fu.sh:1865-2012`.
11. Replicate changes in `fu.ps1` for Windows support.

**New Fancy Prompt Theme:**
- Add entries to `MENU_LABELS`, `MENU_EMOJIS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`, `MENU_SINGLE_SELECT`.
- Write `_write_prompt_{name}()` heredoc function (see `_write_prompt_purple` pattern at `fu.sh:689-982`).
- Write `create_fancy_prompt_{name}()` and `remove_fancy_prompt_{name}()` functions.

**New Platform Support:**
- Add detection to `detect_platform()` at `fu.sh:160-169` if new OS type.
- Add package manager to `get_pkg_manager()` at `fu.sh:207-240`.
- Add commands to `pkg_install`, `pkg_remove`, `pkg_update`, `pkg_purge` at `fu.sh:245-321`.

**Utilities:**
- Add shared helpers near the top of `fu.sh` (utility layer, lines 1-159).
- Keep functions self-contained; avoid cross-function state coupling.

## Special Directories

**`.planning/`:**
- Purpose: GSD (Get Stuff Done) methodology artifacts.
- Contains: `codebase/` subdirectory with analysis markdown files.
- Generated: Yes (by `/gsd-map-codebase` command).
- Committed: Yes (tracked in git).

**`.git/`:**
- Purpose: Git repository metadata.
- Generated: Yes (by `git init`).
- Committed: Internal to git.

---

*Structure analysis: 2026-05-22*
