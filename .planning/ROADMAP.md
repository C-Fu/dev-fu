# Roadmap: dev-fu / flu.sh

## Overview

Build a zero-dependency, curl-pipe-bash TUI menu system that fetches and executes modular developer environment scripts. The journey starts with a portable POSIX TUI engine (primitives + single-select menu), extends to interactive widgets and hierarchical navigation, adds remote module execution, wires everything together in a single orchestrator script, and finally ports the full system to PowerShell.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: TUI Engine Core** — Portable POSIX terminal primitives, keyboard input, and single-select menu widget (completed 2026-05-23)
- [x] **Phase 2: Interactive Widgets** — Checklist, radio, yes/no, text input widgets with consistent contract (completed 2026-05-24)
- [ ] **Phase 3: Menu System** — Pipe-delimited menu DSL, 3-level submenu navigation with breadcrumbs
- [ ] **Phase 4: Module Architecture** — Remote script fetching, metadata parsing, isolated execution with inline prompts
- [ ] **Phase 5: Integration & Orchestrator** — Full flu.sh script wiring TUI + menus + modules, TTY reattach, spinner, git branch
- [ ] **Phase 6: PowerShell Port** — Full feature parity for Windows and cross-platform PowerShell

## Phase Details

### Phase 1: TUI Engine Core
**Goal**: Developer has a fully portable, POSIX-compliant TUI engine that renders interactive single-select menus with keyboard navigation, working identically across bash, zsh, dash, ash, and busybox sh
**Depends on**: Nothing (first phase)
**Requirements**: ENGN-01, ENGN-02, ENGN-03, ENGN-04, ENGN-05, ENGN-06, ENGN-07, ENGN-08, WDGT-04, INTG-03, INTG-04
**Success Criteria** (what must be TRUE):
  1. User can navigate a list of 20+ items using Up/Down arrows, j/k vi keys, PgUp/PgDn, and Home/End — seeing reverse-video highlight and scroll indicators (↑more/↓more) when content overflows
  2. User can select an item with Enter, cancel with Esc or q, and jump directly to any item by typing its number (multi-digit accumulator)
  3. Script displays a numbered text prompt instead of TUI when TERM=dumb or no TTY is available
  4. Every screen shows a contextual help footer listing available keybindings
  5. Terminal state is fully restored on every exit path including Ctrl-C and signals (INT, TERM, HUP, QUIT) — verified working on bash, dash, and busybox sh
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md — Terminal primitives, signal handling, shell-aware input system, and fallback prompt
- [x] 01-02-PLAN.md — Single-select menu widget with navigation, rendering, and number jump

### Phase 2: Interactive Widgets
**Goal**: Users can interact with checklists, radio lists, text inputs, and confirmation dialogs using consistent keyboard patterns, all built on the Phase 1 TUI engine
**Depends on**: Phase 1
**Requirements**: WDGT-01, WDGT-02, WDGT-03, WDGT-05, WDGT-06
**Success Criteria** (what must be TRUE):
  1. User can toggle individual items in a multi-select checklist with Space key ([x]/[ ]) and toggle all items at once with Select All / Deselect All keys
  2. User is prompted with Yes/No confirmation before destructive operations (remove, uninstall) and can proceed or cancel
  3. User can choose exactly one option from a radio-button list with (•)/(○) indicators
  4. User can enter freeform text in an inline input with cursor movement and backspace editing
**Plans**: 3 plans

Plans:
- [x] 02-01-PLAN.md — Extend key reader with Ctrl+D/Delete/*/- keys + implement tui_checklist() multi-select checkbox widget
- [x] 02-02-PLAN.md — Implement tui_radio() single-select and tui_yesno() confirmation dialog widgets
- [x] 02-03-PLAN.md — Implement tui_text_input() freeform text entry widget with line editing
**UI hint**: yes

### Phase 3: Menu System
**Goal**: Users navigate hierarchical menus defined by a simple DSL, with breadcrumbs and intuitive back navigation across 3 levels of nesting
**Depends on**: Phase 1
**Requirements**: MENU-01, MENU-02, MENU-03, MENU-04
**Success Criteria** (what must be TRUE):
  1. User can navigate up to 3 levels of nested submenus (Main → Category → Sub-option) and return to the parent menu with Esc or Left arrow
  2. User sees a breadcrumb trail showing current position (e.g., Main > Dev Tools > Python) at every menu level
  3. Menu definitions use a pipe-delimited DSL parseable with awk in POSIX sh — loading and navigating a 50-item definition works correctly with no external dependencies
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md — Menu DSL parser with pipe-delimited awk parsing and tree query functions (flu_menu_load, flu_menu_get_children, flu_menu_is_leaf, flu_menu_get_breadcrumb, flu_menu_get_action)
- [ ] 03-02-PLAN.md — Navigation engine with custom TUI renderer, 3-level submenu event loop, breadcrumb display, Left arrow back-navigation, and numbered fallback mode
**UI hint**: yes

### Phase 4: Module Architecture
**Goal**: Scripts fetch, validate, and execute remote module scripts from GitHub on demand — with platform context, inline parameter collection, and clear result reporting
**Depends on**: Phase 1, Phase 2
**Requirements**: MODL-01, MODL-02, MODL-03, MODL-04, MODL-05
**Success Criteria** (what must be TRUE):
  1. User can select a menu option that triggers a remote module script to be fetched from GitHub (curl with wget fallback) and executed
  2. Module scripts declare metadata (name, args, platforms) via structured comment headers that the system parses and validates before execution
  3. Modules execute in isolated subshells receiving platform context (FLU_OS, FLU_DISTRO, FLU_PKG_MGR, etc.) via environment variables
  4. Before module execution, the user is prompted for variable parameters via inline prompts (radio, text, yes/no) — e.g., choosing global vs local install scope
  5. Module results display to the user with clear success/failure status and actionable recovery hints on failure
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Integration & Orchestrator
**Goal**: flu.sh is a complete, working single-file script that wires TUI, menus, and modules together — deployable via curl-pipe-bash and coexisting with fu.sh on a dedicated development branch
**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4
**Requirements**: ENGN-09, INTG-01, INTG-02, INTG-05, GIT-01
**Success Criteria** (what must be TRUE):
  1. User can run flu.sh via curl-pipe-bash and it correctly reattaches to /dev/tty for interactive TUI display
  2. A rotating spinner displays during any network fetch operation so the user knows the script hasn't hung
  3. Error messages include actionable recovery hints (not just "failed") — the user always knows what to do next
  4. flu.sh coexists with fu.sh — both scripts are independent, non-conflicting, and can coexist in the same repository
  5. Development occurs on branch `flu.sh`, merged to `main` when validated and stable
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: PowerShell Port
**Goal**: Windows and cross-platform PowerShell users have full feature parity with the POSIX flu.sh — same menus, widgets, navigation, and module execution
**Depends on**: Phase 5
**Requirements**: PS-01, PS-02, PS-03
**Success Criteria** (what must be TRUE):
  1. PowerShell users get the same TUI menu system with widgets, submenu navigation, and inline prompts as flu.sh
  2. PowerShell port fetches and executes the same remote modules with adapted argument passing for the Windows ecosystem
  3. The port works on both PowerShell 5.1 (Windows built-in) and PowerShell 7 (cross-platform)
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order. With parallelization enabled:
- Phase 1 (foundation, no parallelism)
- Phase 2 + Phase 3 (parallel — both build on Phase 1, independent of each other)
- Phase 4 (needs Phase 2 for inline prompt widgets)
- Phase 5 (needs all prior phases)
- Phase 6 (needs complete system from Phase 5)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. TUI Engine Core | 2/2 | Complete | 2026-05-23 |
| 2. Interactive Widgets | 3/3 | Complete | 2026-05-24 |
| 3. Menu System | 1/2 | In Progress|  |
| 4. Module Architecture | 0/? | Not started | - |
| 5. Integration & Orchestrator | 0/? | Not started | - |
| 6. PowerShell Port | 0/? | Not started | - |
