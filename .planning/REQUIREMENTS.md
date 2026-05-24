# Requirements: dev-fu / flu.sh

**Defined:** 2026-05-23
**Core Value:** A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### TUI Engine

- [ ] **ENGN-01**: User can navigate menu items with Up/Down arrow keys and j/k vi keys
- [ ] **ENGN-02**: User can select current item with Enter, cancel/go back with Esc or q
- [ ] **ENGN-03**: Currently highlighted item displays with reverse-video (`\033[7m`) indicator
- [ ] **ENGN-04**: User sees scroll indicators (↑more/↓more) when list content exceeds visible area
- [ ] **ENGN-05**: User can paginate through long lists with PgUp/PgDn keys
- [ ] **ENGN-06**: User can jump to first/last item with Home/End keys
- [ ] **ENGN-07**: User can jump directly to an item by typing its number (multi-digit accumulator)
- [ ] **ENGN-08**: Script renders numbered text prompt fallback when TERM=dumb or no TTY available
- [ ] **ENGN-09**: Script reattaches to /dev/tty when invoked via curl-pipe-bash

### Widgets

- [ ] **WDGT-01**: User can toggle individual items in a multi-select checklist with Space key ([x]/[ ])
- [ ] **WDGT-02**: User can toggle all items at once with Select All / Deselect All key
- [ ] **WDGT-03**: User is prompted with Yes/No confirmation before destructive operations (remove, uninstall)
- [ ] **WDGT-04**: Every screen displays a contextual help footer with available keybindings
- [ ] **WDGT-05**: User can choose exactly one option from a radio-button list (•)/(○) — single-select
- [ ] **WDGT-06**: User can enter freeform text in an inline text input with cursor movement and backspace

### Menu System

- [ ] **MENU-01**: Menu supports up to 3 levels of nested submenus (Main → Category → Sub-option)
- [ ] **MENU-02**: User sees a breadcrumb trail showing current position (e.g., Main > Dev Tools > Python)
- [ ] **MENU-03**: User can return to parent menu with Esc or Left arrow key
- [ ] **MENU-04**: Menu definitions use a pipe-delimited DSL parseable with awk in POSIX sh

### Module Architecture

- [ ] **MODL-01**: Script fetches module scripts from remote GitHub URLs on demand (curl with wget fallback)
- [ ] **MODL-02**: Module scripts declare metadata (name, args, platforms) via structured comment headers
- [ ] **MODL-03**: Modules execute in isolated subshells receiving platform context via environment variables (FLU_OS, FLU_DISTRO, FLU_PKG_MGR, etc.)
- [ ] **MODL-04**: Inline prompts (radio, text, yes/no) collect variable parameters before module execution
- [ ] **MODL-05**: Module output is displayed to user with success/failure status and recovery hints on failure

### Integration

- [ ] **INTG-01**: Rotating spinner displays during network fetch operations
- [ ] **INTG-02**: Error messages include actionable recovery hints (not just "failed")
- [ ] **INTG-03**: Core TUI engine code is POSIX sh compatible — works on bash, zsh, dash, ash, busybox sh
- [ ] **INTG-04**: Terminal state is fully restored on every exit path (signal traps for INT, TERM, HUP, QUIT)
- [ ] **INTG-05**: flu.sh coexists with fu.sh — both are independent, non-conflicting scripts

### PowerShell

- [x] **PS-01**: PowerShell port (flu.ps1) implements the same TUI menu system, widgets, submenu navigation, and inline prompts
- [ ] **PS-02**: PowerShell port fetches and executes the same remote modules with adapted argument passing
- [ ] **PS-03**: PowerShell port works on PowerShell 5.1 (Windows) and PowerShell 7 (cross-platform)

### Git

- [ ] **GIT-01**: Development occurs on branch `flu.sh`, merged to `main` when validated and stable

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### TUI Enhancements

- **ENGN-10**: Terminal resize handling — script detects SIGWINCH and re-renders to new dimensions
- **ENGN-11**: Substring search/filter — user types to narrow visible list items in real-time

### Module Enhancements

- **MODL-06**: Module registry with auto-discovery — manifest.tsv on GitHub lists all available modules
- **MODL-07**: Module caching with TTL — fetched scripts cached in /tmp with age-based invalidation
- **MODL-08**: SHA256 checksum verification for remote module scripts before execution

### Integration Enhancements

- **INTG-06**: CLI batch mode — `flu.sh --install python --global` for non-interactive scripting
- **INTG-07**: Color themes via FLU_THEME env var (dracula, solarized, monokai presets)
- **INTG-08**: Progress bar for known-length download operations
- **INTG-09**: Contextual description panel — 2-3 line description below menu when cursor on item
- **INTG-10**: Module execution logging to file with timestamps

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Fuzzy search | Pathological in POSIX sh; use substring filter or pipe to fzf |
| Mouse support | Inconsistent across terminals/SSH; project philosophy is keyboard-only |
| Configuration file / state persistence | Stateless design is the identity; env vars for customization |
| Plugin hot-reload / filesystem watcher | Not a long-running daemon; modules fetched per-invocation |
| Internationalization (i18n) | Terminal i18n is a nightmare (CJK width, RTL); English-only |
| Embedded TUI compositor / window manager | Pure ANSI; sequential full-screen widgets, not split panes |
| Auto-update for flu.sh | Manual curl-pipe-bash or git pull is intentional |
| Interactive dependency resolution | Modules handle their own deps internally like existing fu.sh |
| GUI / web interface | Terminal-only identity |
| Complex input validation widgets | No date pickers, file browsers, dropdowns — text + regex only |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENGN-01 | Phase 1 | Pending |
| ENGN-02 | Phase 1 | Pending |
| ENGN-03 | Phase 1 | Pending |
| ENGN-04 | Phase 1 | Pending |
| ENGN-05 | Phase 1 | Pending |
| ENGN-06 | Phase 1 | Pending |
| ENGN-07 | Phase 1 | Pending |
| ENGN-08 | Phase 1 | Pending |
| ENGN-09 | Phase 5 | Pending |
| WDGT-01 | Phase 2 | Pending |
| WDGT-02 | Phase 2 | Pending |
| WDGT-03 | Phase 2 | Pending |
| WDGT-04 | Phase 1 | Pending |
| WDGT-05 | Phase 2 | Pending |
| WDGT-06 | Phase 2 | Pending |
| MENU-01 | Phase 3 | Pending |
| MENU-02 | Phase 3 | Pending |
| MENU-03 | Phase 3 | Pending |
| MENU-04 | Phase 3 | Pending |
| MODL-01 | Phase 4 | Pending |
| MODL-02 | Phase 4 | Pending |
| MODL-03 | Phase 4 | Pending |
| MODL-04 | Phase 4 | Pending |
| MODL-05 | Phase 4 | Pending |
| INTG-01 | Phase 5 | Pending |
| INTG-02 | Phase 5 | Pending |
| INTG-03 | Phase 1 | Pending |
| INTG-04 | Phase 1 | Pending |
| INTG-05 | Phase 5 | Pending |
| PS-01 | Phase 6 | In Progress (2/5 plans complete) |
| PS-02 | Phase 6 | Pending |
| PS-03 | Phase 6 | Pending |
| GIT-01 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-23*
*Last updated: 2026-05-23 after roadmap creation*
