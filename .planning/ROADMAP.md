# Roadmap: dev-fu / flu.sh

## Milestones

- ✅ **v1.0 flu.sh** — Phases 1-6 (shipped 2026-05-25)
- 🚧 **v1.1 Feature Parity & Polish** — Phases 7-9 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (7, 8, 9): Planned milestone work
- Decimal phases (7.1, 7.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

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

### 🚧 v1.1 Feature Parity & Polish (In Progress)

**Milestone Goal:** flu.sh reaches full feature parity with fu.sh (all 18 operations), gets a polished intro screen, and README restructuring makes flu.sh the primary project face.

- [x] **Phase 7: Feature Parity** — All 18 fu.sh menu options in flu.sh TUI with emoji labels, category submenus, and working module scripts with install/remove and CLI params (completed 2026-05-25)
- [x] **Phase 8: Intro Polish** — ASCII dev-fu logo and platform detection info on flu.sh startup (completed 2026-05-25)
- [ ] **Phase 9: Documentation** — README restructured with flu.sh as primary, fu.sh docs moved to README-Fu.md

## Phase Details

### Phase 7: Feature Parity
**Goal**: flu.sh TUI menu offers all 18 fu.sh operations through category-grouped submenus with emoji-prefixed labels, backed by working module scripts that support install, remove, and CLI parameter passing
**Depends on**: Phase 6 (v1.0 complete system)
**Requirements**: MENU-05, MENU-06, MENU-07, MODL-06, MODL-07, MODL-08
**Success Criteria** (what must be TRUE):
  1. User can navigate the menu to find all 18 fu.sh operations organized under category submenus: Diagnostics, Containers, Languages & Runtimes, Productivity, Terminal
  2. Every menu item displays an emoji-prefixed label matching fu.sh visual conventions
  3. User selects any tool from the menu and the corresponding remote module script fetches, accepts collected parameters (e.g., --scope global), and executes install/remove successfully
   4. Each module script supports both install and remove modes where fu.sh had paired operations, extracted from fu.sh's existing logic
**Plans**: 3 plans

Plans:
- [x] 07-01-PLAN.md — menu.db expansion with all 18 fu.sh operations across 6 categories, action ID registry
- [x] 07-02-PLAN.md — 18 module scripts for package-manager-based tools (Go, Rust, Python, NVM+Node, Bun, PHP+Laravel, Yarn, Docker, Tailscale) — install + remove
- [x] 07-03-PLAN.md — 13 module scripts for shell config, settings, diagnostics (Fancy Prompts, Avahi, OpenCode+GSD, GitHub Token, Mouse Reporting, Status Check, Compare, Upgrade All)

**UI hint**: yes

### Phase 8: Intro Polish
**Goal**: flu.sh greets users with a branded intro screen showing the ASCII dev-fu logo and detected platform information before the menu loads
**Depends on**: Phase 7
**Requirements**: POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):
  1. User launching flu.sh sees the ASCII "dev-fu" LEGO-style block art centered on screen before the menu loads
  2. The intro screen displays detected platform information (OS, distro, package manager, architecture) alongside the logo
  3. Logo and platform info render correctly across bash, zsh, dash, ash (all POSIX shells)
**Plans**: 1 plan

Plans:
- [x] 08-01-PLAN.md — ASCII dev-fu logo rendered in magenta via _flu_render_logo() with platform info box below

**UI hint**: yes

### Phase 9: Documentation
**Goal**: README.md presents flu.sh as the primary project with comprehensive usage docs, while fu.sh documentation lives in README-Fu.md with cross-references
**Depends on**: Phase 8
**Requirements**: DOC-01, DOC-02
**Success Criteria** (what must be TRUE):
  1. README.md focuses on flu.sh with clear sections for curl-pipe-bash usage, features, menu structure, module architecture, supported platforms, and troubleshooting
  2. README-Fu.md contains all fu.sh-specific documentation with a prominent cross-reference link back to README.md
  3. Malaysian translations (README.ms-MY.md, README-Fu.ms-MY.md) match their English counterparts
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 7 → 8 → 9

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. TUI Engine Core | v1.0 | 2/2 | Complete | 2026-05-23 |
| 2. Interactive Widgets | v1.0 | 3/3 | Complete | 2026-05-24 |
| 3. Menu System | v1.0 | 2/2 | Complete | 2026-05-24 |
| 4. Module Architecture | v1.0 | 3/3 | Complete | 2026-05-24 |
| 5. Integration & Orchestrator | v1.0 | 0/3 | Complete | 2026-05-24 |
| 6. PowerShell Port | v1.0 | 5/5 | Complete | 2026-05-25 |
| 7. Feature Parity | v1.1 | 3/3 | Complete    | 2026-05-25 |
| 8. Intro Polish | v1.1 | 1/1 | Complete    | 2026-05-25 |
| 9. Documentation | v1.1 | 0/0 | Not started | - |
