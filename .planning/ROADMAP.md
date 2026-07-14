# Roadmap: dev-fu / flu.sh

## Milestones

- ✅ **v1.0 flu.sh** — Phases 1-6 (shipped 2026-05-25)
- ✅ **v1.1 Feature Parity & Polish** — Phases 7-9 (shipped 2026-05-25)
- 🚧 **v2.0 Modular Ecosystem** — Phases 10-14 (in progress)
- 📋 **v3.0 Rust Binary** — Phases 15-21 (complete)

## Phases

<details>
<summary>✅ v1.0 flu.sh (Phases 1-6) — SHIPPED 2026-05-25</summary>

- [x] **Phase 1: TUI Engine Core** — Portable POSIX terminal primitives, keyboard input, and single-select menu widget (completed 2026-05-23)
- [x] **Phase 2: Interactive Widgets** — Checklist, radio, yes/no, text input widgets with consistent contract (completed 2026-05-24)
- [x] **Phase 3: Menu System** — Pipe-delimited menu DSL, 3-level submenu navigation with breadcrumbs (completed 2026-05-24)
- [x] **Phase 4: Module Architecture** — Remote script fetching, metadata parsing, isolated execution with inline prompts (completed 2026-05-24)
- [x] **Phase 5: Integration & Orchestrator** — Full flu.sh script wiring TUI + menus + modules, TTY reattach, spinner, git branch (completed 2026-05-24)
- [x] **Phase 6: PowerShell Port** — Full feature parity for Windows and cross-platform PowerShell (completed 2026-05-25)

*See `.planning/milestones/v1.0-ROADMAP.md` for full details.*

</details>

<details>
<summary>✅ v1.1 Feature Parity & Polish (Phases 7-9) — SHIPPED 2026-05-25</summary>

- [x] **Phase 7: Feature Parity** — All 18 fu.sh operations in TUI menu with module scripts (completed 2026-05-25)
- [x] **Phase 8: Intro Polish** — ASCII dev-fu logo and platform info on startup (completed 2026-05-25)
- [x] **Phase 9: Documentation** — README restructured with flu.sh as primary (completed 2026-05-25)

*See `.planning/milestones/v1.1-ROADMAP.md` for full details.*

</details>

### 🚧 v2.0 Modular Ecosystem (In Progress)

**Milestone Goal:** Transform flu.sh from a functional TUI into a production-grade modular ecosystem — hardened module pipeline, modern CLI tool suite, and cross-platform PowerShell parity.

- [ ] **Phase 10: Module Pipeline Hardening** — SHA256 verification, caching, progress bar, and execution logging
- [ ] **Phase 11: Modern CLI Tools** — lazygit, starship, zoxide, and eza install/remove modules
- [x] **Phase 12: Advanced Module System** — CLI batch mode and module registry with auto-discovery
- [ ] **Phase 13: UI & Terminal Polish** — Color themes and terminal resize handling
- [ ] **Phase 14: PowerShell Parity** — flu.ps1 mirrors all v1.1 + v2.0 features

## Phase Details

### Phase 10: Module Pipeline Hardening
**Goal**: Users can trust fetched modules are authentic, see download progress, benefit from caching, and review execution history
**Depends on**: Phase 9 (v1.1 complete)
**Requirements**: SECU-01, PERF-01, PERF-02, ADVN-03
**Success Criteria** (what must be TRUE):
  1. User sees a SHA256 mismatch error and module execution is blocked when a fetched script is tampered or corrupted
  2. User sees a progress bar with bytes received during module script downloads
  3. User's second run of the same module skips the download (cache hit) and expired cache entries are re-fetched
  4. User can inspect a local log file showing tool name, action, success/failure, version, and timestamp for every module execution
**Plans**: 2 plans

Plans:
- [ ] 10-01-PLAN.md — SHA256 checksums, module caching, and download progress (SECU-01, PERF-01, PERF-02)
- [ ] 10-02-PLAN.md — Execution logging to TSV file (ADVN-03)

### Phase 11: Modern CLI Tools
**Goal**: Users can install and remove four modern CLI tools (lazygit, starship, zoxide, eza) through the flu.sh menu
**Depends on**: Phase 10
**Requirements**: TOOL-01, TOOL-02, TOOL-03, TOOL-04
**Success Criteria** (what must be TRUE):
  1. User can install lazygit via the menu and launch it as a TUI git client
  2. User can install starship and see the cross-shell prompt active in their current shell session
  3. User can install zoxide and use `z` to jump to frecency-ranked directories
  4. User can install eza and use it as a colorized, modern `ls` replacement
  5. User can remove any of the four tools via the menu and the tool is fully uninstalled
**Plans**: 2 plans

Plans:
- [ ] 11-01-PLAN.md — lazygit and starship install/remove scripts + menu.db entries (TOOL-01, TOOL-02)
- [ ] 11-02-PLAN.md — zoxide and eza install/remove scripts + menu.db entries + README + MANIFEST (TOOL-03, TOOL-04)

### Phase 12: Advanced Module System
**Goal**: Users can run flu.sh non-interactively from the command line and browse/discover available modules from a registry
**Depends on**: Phase 10
**Requirements**: ADVN-01, ADVN-02
**Success Criteria** (what must be TRUE):
  1. User can run `flu.sh --install go,rust,starship --yes` and have all three tools installed without entering the TUI
  2. User can run `flu.sh --list` to see all available modules including community-contributed ones from the registry
  3. User can discover and install a community-contributed module not bundled with flu.sh by default
**Plans**: 2 plans

Plans:
- [x] 12-01-PLAN.md — CLI batch mode: --install, --remove, --list, --yes flags (ADVN-01)
- [x] 12-02-PLAN.md — Module registry with auto-discovery and community modules (ADVN-02)

### Phase 13: UI & Terminal Polish
**Goal**: Users can customize flu.sh's appearance with color themes and the menu stays usable when the terminal is resized
**Depends on**: Phase 10
**Requirements**: UI-01, UI-02
**Success Criteria** (what must be TRUE):
  1. User can set `FLU_THEME=light` and see a light color palette throughout the menu, with fallback to default for unknown theme names
  2. User can set `FLU_THEME=monochrome` and see a no-color output suitable for non-color terminals
  3. User can resize the terminal window while the menu is displayed and the menu redraws correctly without losing the current selection
**Plans**: TBD

Plans:
- [ ] 13-01: TBD

### Phase 14: PowerShell Parity
**Goal**: Windows and PowerShell users get all v1.1 + v2.0 features in flu.ps1 — expanded menu, module scripts, checksums, caching, CLI batch mode, color themes, and modern CLI tools
**Depends on**: Phase 10, Phase 11, Phase 12, Phase 13
**Requirements**: PS-01
**Success Criteria** (what must be TRUE):
  1. User running flu.ps1 sees the same expanded menu with all v1.1 + v2.0 tool entries as flu.sh
  2. User running flu.ps1 benefits from SHA256 checksum verification and module caching during script fetching
  3. User running flu.ps1 can use CLI batch mode (`flu.ps1 --install ... --yes`) and color themes (`$env:FLU_THEME`)
  4. User running flu.ps1 can install/remove the four modern CLI tools (lazygit, starship, zoxide, eza) where platform-appropriate
**Plans**: 3 plans

Plans:
- [ ] 14-01-PLAN.md — Core module pipeline: caching, SHA256 checksums, execution logging, .ps1 resolution (PS-01)
- [ ] 14-02-PLAN.md — CLI batch mode, ASCII logo, color themes, startup display (PS-01)
- [ ] 14-03-PLAN.md — .ps1 module scripts (65+), fust Windows cross-compile (PS-01)

### 📋 v3.0 Rust Binary (Planned)

**Milestone Goal:** Refactor the entire flu.sh POSIX shell ecosystem into a single portable Rust binary — zero runtime dependencies, cross-platform, with all TUI menus, module fetching, registry, and execution embedded in one static binary.

- [x] **Phase 15: Rust Project Scaffold + CLI** — Cargo project, clap CLI args, platform detection (completed 2026-06-11)
- [x] **Phase 16: TUI Engine** — Port tui.sh terminal primitives, box drawing, keyboard input, widgets (select, checklist, radio, text input, yesno) (completed 2026-06-11)
- [x] **Phase 17: Menu System** — Port menu.sh DSL parser, hierarchical navigation, embed menu.db at compile time (completed 2026-06-11)
- [x] **Phase 18: Module Pipeline** — Port modules.sh fetch/cache/SHA256/execute subsystem (completed 2026-06-11)
- [x] **Phase 19: Registry + Batch Mode** — Community module registry, CLI batch commands (--install, --remove, --list) (completed 2026-06-11)
- [x] **Phase 20: Integration** — Logo, startup display, main event loop, error recovery, signal handling (completed 2026-06-11)
- [x] **Phase 21: Build & Distribution** — Cross-compile targets, CI, release binaries, curl-pipe-bash installer (completed 2026-06-11)

## v3.0 Phase Details

### Phase 15: Rust Project Scaffold + CLI
**Goal**: Establish the Rust project with CLI argument parsing and platform detection that mirrors flu.sh's CLI interface
**Depends on**: None (foundational)
**Success Criteria** (what must be TRUE):
  1. `cargo build` produces a `fust` binary that runs on Linux and macOS
  2. `fust --help` shows the same flags as `flu.sh --help`
  3. `fust --list` outputs the menu structure from embedded menu.db
  4. Platform detection sets OS, distro, package manager, arch (matching flu.sh's FLU_* variables)
**Plans**: 1 plan

Plans:
- [x] 15-01-PLAN.md — Cargo project scaffold, clap CLI, platform detection, menu.db parser

### Phase 16: TUI Engine
**Goal**: Port the entire tui.sh rendering engine — terminal control, box drawing, cursor positioning, keyboard input, and all interactive widgets
**Depends on**: Phase 15
**Success Criteria** (what must be TRUE):
  1. TUI renders a bordered box with centered title matching flu.sh's visual style
  2. All 5 widget types work: select, checklist, radio, text input, yes/no
  3. Keyboard navigation (arrow keys, vim keys, enter, escape, pgup/pgdn) works identically to flu.sh
  4. Terminal is always restored on exit (including signal interrupts)
**Plans**: 2 plans (Wave 1: 16-01, Wave 2: 16-02)

Plans:
- [x] 16-01-PLAN.md — Terminal primitives, box drawing, keyboard input, cursor control (ratatui + crossterm)
- [x] 16-02-PLAN.md — Interactive widgets: select, checklist, radio, text input, yesno

### Phase 17: Menu System
**Goal**: Port the hierarchical menu DSL parser and 3-level navigation engine from menu.sh
**Depends on**: Phase 16
**Success Criteria** (what must be TRUE):
  1. Menu renders identically to flu.sh with colored borders, breadcrumbs, and numbered items
  2. Users navigate 3-level hierarchy (category → subcategory → action) with keyboard
  3. Space-bar queue (multi-select) works for batch execution
  4. menu.db is embedded at compile time and parsed at startup
**Plans**: 1 plan

Plans:
- [x] 17-01-PLAN.md — Menu DSL parser, navigation engine, rendering, embedded menu.db

### Phase 18: Module Pipeline
**Goal**: Port the module fetch, cache, SHA256 verify, metadata parse, and execute subsystem from modules.sh
**Depends on**: Phase 15
**Success Criteria** (what must be TRUE):
  1. Modules are fetched from GitHub with retry logic (3 attempts)
  2. SHA256 checksums are verified against MANIFEST.sha256
  3. Module scripts are cached locally with TTL expiry
  4. Modules execute in isolated subprocesses with timeout enforcement
  5. Metadata (@name, @platforms, @version, @params, @deps, @timeout) is parsed from comment headers
**Plans**: 2 plans

Plans:
- [x] 18-01-PLAN.md — Module fetch, cache, SHA256 verification, HTTP client (reqwest + sha2) (SECU-01, PERF-01, PERF-02)

- [x] 18-02-PLAN.md — Metadata parser, parameter collection, isolated execution with timeout (ADVN-03)
### Phase 19: Registry + Batch Mode
**Goal**: Port community module registry and CLI batch mode from modules.sh/flu.sh
**Depends on**: Phase 17, Phase 18
**Success Criteria** (what must be TRUE):
  1. `flu --install go,rust --yes` installs both tools without TUI interaction
  2. `flu --list --json` outputs JSON array of all modules including community ones
  3. Community module registry is fetched, cached, and merged with official modules
  4. Dynamic menu assembly merges official menu.db + community modules at runtime
**Plans**: 1 plan

Plans:
- [x] 19-01-PLAN.md — Registry fetch/cache, batch run, batch list, dynamic menu assembly

### Phase 20: Integration
**Goal**: Wire everything together — logo, startup display, main event loop, error recovery, signal handling
**Depends on**: Phase 17, Phase 18, Phase 19
**Success Criteria** (what must be TRUE):
  1. Running `flu` with no flags shows the branded dev-fu ASCII logo, then platform info, then the main menu
  2. Selecting a menu item fetches and executes the module with progress feedback
  3. Exit codes are mapped to actionable user hints (timeout, permission denied, etc.)
  4. Ctrl-C always restores terminal state cleanly
**Plans**: 1 plan

Plans:
- [x] 20-01-PLAN.md — Logo rendering, startup display, main event loop, error recovery, signal handling

### Phase 21: Build & Distribution
**Goal**: Cross-compile for all target platforms, set up CI, and create a curl-pipe-bash installer
**Depends on**: Phase 20
**Success Criteria** (what must be TRUE):
  1. Static binaries are produced for: linux-amd64, linux-arm64, macos-amd64, macos-arm64
  2. `curl -fsSL https://flu.sh | bash` downloads and runs the correct binary
  3. Binary size is under 5MB (stripped, static)
  4. GitHub Actions CI builds and releases on tag push
**Plans**: 1 plan

Plans:
- [x] 21-01-PLAN.md — Cross-compile setup, GitHub Actions CI, release workflow, install script

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. TUI Engine Core | v1.0 | 2/2 | Complete | 2026-05-23 |
| 2. Interactive Widgets | v1.0 | 3/3 | Complete | 2026-05-24 |
| 3. Menu System | v1.0 | 2/2 | Complete | 2026-05-24 |
| 4. Module Architecture | v1.0 | 3/3 | Complete | 2026-05-24 |
| 5. Integration & Orchestrator | v1.0 | 3/3 | Complete | 2026-05-24 |
| 6. PowerShell Port | v1.0 | 5/5 | Complete | 2026-05-25 |
| 7. Feature Parity | v1.1 | 3/3 | Complete | 2026-05-25 |
| 8. Intro Polish | v1.1 | 1/1 | Complete | 2026-05-25 |
| 9. Documentation | v1.1 | 3/3 | Complete | 2026-05-25 |
| 10. Module Pipeline Hardening | v2.0 | 0/2 | Planned | - |
| 11. Modern CLI Tools | v2.0 | 0/2 | Planned | - |
| 12. Advanced Module System | v2.0 | 2/2 | Complete | 2026-05-28 |
| 13. UI & Terminal Polish | v2.0 | 0/? | Not started | - |
| 14. PowerShell Parity | v2.0 | 0/? | Not started | - |
| 15. Rust Project Scaffold + CLI | v3.0 | 1/1 | Complete | 2026-06-11 |
| 16. TUI Engine | v3.0 | 2/2 | Complete | 2026-06-11 |
| 17. Menu System | v3.0 | 1/1 | Complete | 2026-06-11 |
| 18. Module Pipeline | v3.0 | 2/2 | Complete | 2026-06-11 |
| 19. Registry + Batch Mode | v3.0 | 1/1 | Complete | 2026-06-11 |
| 20. Integration | v3.0 | 1/1 | Complete | 2026-06-11 |
| 21. Build & Distribution | v3.0 | 1/1 | Complete | 2026-06-11 |
