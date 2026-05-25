# Requirements: dev-fu / flu.sh v1.1

**Defined:** 2026-05-25
**Milestone:** v1.1 Feature Parity & Polish
**Core Value:** A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## v1.1 Requirements

### Documentation & README

- [ ] **DOC-01**: README.md and README.ms-MY.md focus on flu.sh — how to run remotely (curl-pipe-bash, clone+run), features, menu structure, module architecture, supported platforms, troubleshooting
- [ ] **DOC-02**: Existing fu.sh documentation moved to README-Fu.md and README-Fu.ms-MY.md with cross-reference links back to the main README

### Menu Expansion

- [ ] **MENU-05**: menu.db expanded to cover all 18 fu.sh menu options (Status Check, Compare With Latest, Upgrade All Tools, Set GitHub Token, Docker, Fancy Prompt Purple-Pink, Fancy Prompt Shades of Blue, Hostname Discovery, Go, Rust, Python, NVM+Node, Bun, Yarn, Mouse Reporting, PHP+Laravel, Tailscale, OpenCode+GSD)
- [ ] **MENU-06**: Menu items use emoji-prefixed labels matching fu.sh style for visual appeal in the TUI
- [ ] **MENU-07**: Menu items grouped by category using submenu nesting (Diagnostics, Containers, Languages & Runtimes, Productivity, Terminal)

### Module Scripts

- [ ] **MODL-06**: Module scripts created for each tool with real install logic extracted from fu.sh (Docker, Go, Rust, Python, NVM/Node, Bun, Fancy Prompts, Hostname Discovery, Yarn, Mouse Reporting, PHP/Laravel, Tailscale, OpenCode/GSD)
- [ ] **MODL-07**: Module scripts include install+remove paired functions where applicable, extracted from fu.sh
- [ ] **MODL-08**: Module scripts accept collected parameters passed via command-line args (e.g., `--scope global`)

### Visual Polish

- [ ] **POLISH-01**: flu.sh startup intro screen displays the big ASCII "dev-fu" logo art from fu.sh (the LEGO-style block characters) centered on screen
- [ ] **POLISH-02**: Platform info displayed alongside the logo (OS, distro, package manager, architecture) before entering the menu

## Future Requirements

Deferred to future milestones.

- Module caching with TTL (was MODL-07 v1.0)
- SHA256 checksum verification for modules (was MODL-08 v1.0)
- Module registry with auto-discovery (was MODL-06 v1.0)
- CLI batch mode for flu.sh (was INTG-06 v1.0)
- Color themes via FLU_THEME env var (was INTG-07 v1.0)
- Progress bar for downloads (was INTG-08 v1.0)
- Module execution logging (was INTG-10 v1.0)
- Terminal resize handling (was ENGN-10 v1.0)

## Out of Scope

| Feature | Reason |
|---------|--------|
| New tools not in fu.sh | Feature parity milestone — match existing, don't add new |
| flu.ps1 feature parity update | PowerShell port already complete at parity |
| Module registry / caching | Deferred to v2 — module pipeline works, caching adds complexity |
| CLI batch mode | Deferred to v2 — interactive TUI is the v1 identity |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOC-01 | — | Pending |
| DOC-02 | — | Pending |
| MENU-05 | — | Pending |
| MENU-06 | — | Pending |
| MENU-07 | — | Pending |
| MODL-06 | — | Pending |
| MODL-07 | — | Pending |
| MODL-08 | — | Pending |
| POLISH-01 | — | Pending |
| POLISH-02 | — | Pending |

**Coverage:**
- v1.1 requirements: 10 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 10

---
*Requirements defined: 2026-05-25*
*Milestone: v1.1 Feature Parity & Polish*
