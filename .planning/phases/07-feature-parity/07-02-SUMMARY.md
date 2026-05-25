---
phase: 07-feature-parity
plan: 02
subsystem: modules
tags: [modules, posix-sh, package-manager, curl-pipe, install, remove, idempotent]
requires:
  - phase: 07-feature-parity
    plan: 01
    provides: [menu-database-v1.1, action-id-convention, module-contract]
provides:
  - "18 POSIX sh module scripts: install+remove for Go, Rust, Python, NVM+Node, Bun, PHP+Laravel, Yarn, Docker, Tailscale"
  - "Standard module pattern: @metadata headers, FLU_* env vars, _maybe_sudo, _pkg_install/update/remove helpers"
  - "Idempotent installs (command -v guard) and safe removes (existence guard)"
affects:
  - 07-03 (parallel wave 2 — disjoint file set)
  - modules.sh (consumer — flu_module_execute pipeline)
  - flu.sh (consumer — menu action dispatch)

tech-stack:
  added: []
  patterns: [posix-sh-module-script, metadata-at-key-header, idempotent-install-guard, existence-remove-guard, pkg-mgr-dispatch-case]

key-files:
  created:
    - modules/install_bun.sh
    - modules/install_docker.sh
    - modules/install_nvm_node.sh
    - modules/install_php_laravel.sh
    - modules/install_rust.sh
    - modules/install_tailscale.sh
    - modules/install_yarn.sh
    - modules/remove_bun.sh
    - modules/remove_docker.sh
    - modules/remove_go.sh
    - modules/remove_nvm_node.sh
    - modules/remove_php_laravel.sh
    - modules/remove_python.sh
    - modules/remove_rust.sh
    - modules/remove_tailscale.sh
    - modules/remove_yarn.sh
  modified:
    - modules/install_go.sh (replaced demo with fu.sh-extracted logic)
    - modules/install_python.sh (updated with full fu.sh-extracted logic)

key-decisions:
  - "D-04: Fresh POSIX sh scripts following flu.sh conventions — logic extracted from fu.sh, not copied"
  - "D-05: All scripts include @metadata headers, FLU_* env var usage, set -eu strict mode"
  - "D-06: Platform-specific package manager dispatch via FLU_PKG_MGR (apt, apk, dnf, pacman, zypper, brew)"
  - "D-08: Install scripts use command -v idempotent guards; remove scripts use existence guards with 'is not installed' messaging"
  - "Curl-pipe installs (Rust, Bun, NVM, Tailscale) use @timeout: 600; package manager installs use @timeout: 300"
  - "Docker scripts are linux-only (@platforms: linux); others support linux, darwin"
  - "NVM+Node script handles musl (Alpine) edge case with apk fallback per fu.sh pattern"

patterns-established:
  - "module-script-structure: shebang → @metadata header → set -eu → _maybe_sudo() → FLU_PKG_MGR fallback → _pkg_*( helpers → idempotent guard → install/remove logic → success message"
  - "pkg-remove-helper: _pkg_remove() dispatches apt-get remove, apk del, dnf remove, pacman -R, zypper remove, brew uninstall"
  - "curl-pipe-fallback: curl preferred, wget fallback, both absent = error with clear message"

requirements-completed: [MODL-06, MODL-07, MODL-08]

metrics:
  duration: "~8 minutes"
  completed-date: "2026-05-25"
---

# Phase 7 Plan 2: Package-Manager-Based Module Scripts — Summary

**18 POSIX sh module scripts extracting fu.sh install/remove logic into flu.sh's module pipeline, with idempotent guards, platform-aware package manager dispatch, and zero bashisms.**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-25T12:58:00Z
- **Completed:** 2026-05-25T13:06:17Z
- **Tasks:** 2
- **Files created:** 16
- **Files modified:** 2

## Accomplishments

- Created 9 install module scripts: Go, Rust, Python, NVM+Node, Bun, PHP+Laravel, Yarn, Docker, Tailscale
- Created 9 remove module scripts matching each install, including safe existence guards
- All 18 scripts follow the flu.sh module conventions: `@metadata` headers, `FLU_*` env vars, `set -eu`, `_maybe_sudo()`
- Package manager dispatch (`_pkg_install`, `_pkg_update`, `_pkg_remove`) handles apt, apk, dnf, pacman, zypper, brew
- Curl-pipe installs (Rust/rustup, Bun, NVM, Tailscale) use curl with wget fallback
- Edge cases handled: musl/Alpine for NVM+Node, Docker linux-only, Tailscale macOS via brew

## Task Commits

Each task was committed atomically:

1. **Task 1: Create install module scripts for all package-manager-based tools** — `ed50464` (feat)
2. **Task 2: Create remove module scripts for all package-manager-based tools** — `4d1149b` (feat)

## Files Created/Modified

### Install scripts (task 1)
- `modules/install_go.sh` — Go via package manager (golang-go / go for apk)
- `modules/install_rust.sh` — Rust via rustup curl-pipe (no package manager)
- `modules/install_python.sh` — Python + pip + pipx + uv (pkg + curl-pipe for uv)
- `modules/install_nvm_node.sh` — NVM + Node LTS (curl-pipe, musl-aware apk fallback)
- `modules/install_bun.sh` — Bun via bun.sh curl-pipe
- `modules/install_php_laravel.sh` — PHP + Composer + Laravel installer (pkg + composer global)
- `modules/install_yarn.sh` — Yarn via npm global + package manager fallback
- `modules/install_docker.sh` — Docker via get.docker.com script (linux only)
- `modules/install_tailscale.sh` — Tailscale via official install script (brew on macOS)

### Remove scripts (task 2)
- `modules/remove_go.sh` — Remove Go via package manager, note GOPATH
- `modules/remove_rust.sh` — Remove Rust via rustup self-uninstall, clean ~/.cargo + shell rc
- `modules/remove_python.sh` — Remove Python + pip + pipx + uv, clean uv artifacts
- `modules/remove_nvm_node.sh` — Remove NVM directory + clean shell rc (musl/glibc aware)
- `modules/remove_bun.sh` — Remove ~/.bun + clean shell rc PATH entries
- `modules/remove_php_laravel.sh` — Remove PHP packages + composer global remove Laravel
- `modules/remove_yarn.sh` — Remove via npm uninstall + package manager
- `modules/remove_docker.sh` — Stop service, purge packages, clean data, remove docker group
- `modules/remove_tailscale.sh` — tailscale down, package manager remove, clean /var/lib/tailscale

## Verification

All plan verification criteria met:

| Criterion | Result |
|-----------|--------|
| 18 module scripts exist | PASS (18/18) |
| Every script has @name, @platforms, @version | PASS (18/18) |
| Every script has `set -eu` | PASS (18/18) |
| Zero `[[` bashisms | PASS (0 matches) |
| Zero `local` keyword bashisms | PASS (0 matches — path strings excluded) |
| Zero `function` keyword bashisms | PASS (0 matches) |
| Install idempotent guards (`command -v`) — 9 our scripts | PASS |
| Remove existence guards (`is not installed`) | PASS (9/9) |
| Key content: rustup.rs in rust install | PASS |
| Key content: nvm in nvm_node install | PASS |
| Key content: bun.sh/install in bun install | PASS |
| Key content: tailscale.com in tailscale install | PASS |
| Key content: systemctl stop docker in remove_docker | PASS |
| Key content: tailscale down in remove_tailscale | PASS |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no hardcoded empty values, placeholder text, TODO/FIXME comments, or disconnected data sources in any of the 18 module scripts.

## Threat Flags

None — all curl-pipe URLs use HTTPS (T-07-03 mitigated), sudo is gated through _maybe_sudo() (T-07-05 mitigated), @timeout values set per plan spec (T-07-06 accepted). No new endpoints, auth paths, or file access patterns beyond what the threat model addressed.

## Out-of-Scope Discoveries

- **`web.sh`** — untracked file in repo root, not related to this plan. Left as-is per deviation scope boundary rules.

## Next Phase Readiness

- 18 module scripts ready for integration with flu.sh's `flu_module_execute()` pipeline
- Action IDs in menu.db (from plan 07-01) map 1:1 to these script filenames
- No blockers — plan 07-03 (remaining module scripts) has a disjoint file set

---
*Phase: 07-feature-parity*
*Completed: 2026-05-25*
