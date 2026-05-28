# Requirements: dev-fu / flu.sh v2.0

**Defined:** 2026-05-28
**Milestone:** v2.0 Modular Ecosystem
**Core Value:** A single script that works everywhere POSIX (and PowerShell) — zero dependencies, curl-pipe-bash ready — with a professional interactive menu that fetches and executes modular install scripts on demand.

## v2.0 Requirements

### Module Security

- [ ] **SECU-01**: flu.sh verifies SHA256 checksums of fetched module scripts against a manifest before execution, rejecting tampered or corrupted scripts

### Module Performance

- [ ] **PERF-01**: flu.sh caches fetched module scripts locally with a configurable TTL, skipping re-download when cache is valid
- [ ] **PERF-02**: flu.sh displays a progress bar during module script downloads showing bytes received / total

### Advanced Module Features

- [ ] **ADVN-01**: flu.sh supports CLI batch mode for non-interactive execution (e.g., `flu.sh --install go,rust,starship --yes`) without entering the TUI
- [x] **ADVN-02**: flu.sh supports a module registry with auto-discovery, allowing users to browse and install community-contributed module scripts
- [ ] **ADVN-03**: flu.sh logs module execution results (tool, action, success/failure, version, timestamp) to a local log file

### UI & Terminal

- [ ] **UI-01**: flu.sh supports color themes via FLU_THEME env var (dark, light, monochrome, custom) with fallback to default
- [ ] **UI-02**: flu.sh handles terminal resize events during menu display, redrawing the menu without losing state

### Modern CLI Tools

- [ ] **TOOL-01**: flu.sh can install and remove lazygit (TUI git client) via curl-pipe install
- [ ] **TOOL-02**: flu.sh can install and remove starship (cross-shell prompt), replacing or coexisting with fancy prompts
- [ ] **TOOL-03**: flu.sh can install and remove zoxide (smart cd with frecency) via curl-pipe install
- [ ] **TOOL-04**: flu.sh can install and remove eza (modern ls replacement) via curl-pipe or package manager

### Cross-Platform

- [ ] **PS-01**: flu.ps1 mirrors all v1.1 + v2.0 features (expanded menu, module scripts, intro logo, checksums, caching, CLI batch mode, color themes, modern CLI tools)

## Future Requirements

Deferred to future milestones.

- Auto-update mechanism for flu.sh itself
- Configuration file / state persistence
- Localization beyond English + Bahasa Melayu
- Web-based module browser
- Module script sandboxing

## Out of Scope

| Feature | Reason |
|---------|--------|
| GUI or web-based interface | Terminal-only by design |
| Package creation/publishing | Setup utility, not a package manager |
| Additional CLI tools beyond 4 | Ship 4 first, add more in v2.1+ based on user feedback |
| Module script sandboxing | Shell scripts inherently have system access; checksums provide integrity |
| Auto-update for flu.sh | Manual curl-pipe-bash or git pull; defer complexity |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SECU-01 | Phase 10 | Pending |
| PERF-01 | Phase 10 | Pending |
| PERF-02 | Phase 10 | Pending |
| ADVN-03 | Phase 10 | Pending |
| TOOL-01 | Phase 11 | Pending |
| TOOL-02 | Phase 11 | Pending |
| TOOL-03 | Phase 11 | Pending |
| TOOL-04 | Phase 11 | Pending |
| ADVN-01 | Phase 12 | Pending |
| ADVN-02 | Phase 12 | ✓ Complete |
| UI-01 | Phase 13 | Pending |
| UI-02 | Phase 13 | Pending |
| PS-01 | Phase 14 | Pending |

**Coverage:**
- v2.0 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-05-28*
*Milestone: v2.0 Modular Ecosystem*
