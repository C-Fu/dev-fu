# Project Milestones: dev-fu / flu.sh

## v1.1 Feature Parity & Polish (Shipped: 2026-05-25)

**Delivered:** flu.sh reaches full feature parity with fu.sh — 46 module scripts, ASCII logo intro, README restructured with flu.sh as primary.

**Phases completed:** 7-9 (7 plans total)

**Key accomplishments:**
- 31-entry menu database across 5 categories covering all 18 fu.sh operations
- 46 POSIX sh module scripts with install/remove pairs, platform-aware package manager dispatch
- ASCII dev-fu logo with magenta centering and platform info box on startup
- README restructured — flu.sh as primary, fu.sh docs in README-Fu.md
- Bahasa Melayu translations with bidirectional cross-references

**Stats:**
- 51 files changed (+5,857/-770 lines)
- 7,766 total LOC (core + modules)
- 3 phases, 7 plans
- 1 day from first commit to milestone completion

**Git range:** `35d707f` → `a7dac3c`

**Deferred items at close:** 8 (see STATE.md Deferred Items)

---

*Archives: `.planning/milestones/v1.1-ROADMAP.md`, `.planning/milestones/v1.1-REQUIREMENTS.md`*

## v1.0 flu.sh (Shipped: 2026-05-25)

**Delivered:** Zero-dependency, curl-pipe-bash TUI menu system that fetches and executes modular developer environment scripts — POSIX shell + PowerShell, 6 phases, 17 plans.

**Phases completed:** 1-6 (17 plans total)

**Key accomplishments:**
- Portable POSIX TUI engine (2261 lines) with 5 interactive widgets, keyboard navigation, box rendering, fallback mode
- 3-level hierarchical menu system with breadcrumb DSL and 11-key dispatch
- Remote module fetch/execute pipeline with metadata parsing, parameter prompts, and result display
- Complete flu.sh orchestrator with TTY reattachment, spinner, and error recovery
- Full PowerShell port (3176 lines) — flu.ps1, tui.ps1, menu.ps1, modules.ps1 — with PS 5.1 + PS 7 support

**Stats:**
- 40 files created/modified
- 7,442 lines of code (4,266 shell + 3,176 PowerShell)
- 6 phases, 17 plans, ~28 tasks
- ~11 hours from first commit to milestone completion

**Git range:** `feat(01-01)` → `docs(phase-6): complete phase execution`

---

*Archives: `.planning/milestones/v1.0-ROADMAP.md`, `.planning/milestones/v1.0-REQUIREMENTS.md`*
