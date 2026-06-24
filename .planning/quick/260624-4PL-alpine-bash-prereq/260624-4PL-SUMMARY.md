---
status: complete
quick_id: 260624-4PL
slug: alpine-bash-prereq
date: 2026-06-24
---

# Quick Task 260624-4PL: Alpine Bash Prerequisite

## Summary

Added `_ensure_alpine_bash()` helper to `fu-sh/fu.sh` that detects Alpine/musl systems (where bash is not installed by default) and installs it via `apk add bash` before any npm-dependent installation runs. The helper is wired into 4 install functions: `install_opencode_gsd`, `install_nvm_node`, `install_bun`, and `install_yarn`.

## What Changed

### fu-sh/fu.sh
- Added `_ensure_alpine_bash()` helper after `_is_musl()` (line ~1673)
  - Returns 0 immediately if bash is already in PATH (idempotent no-op)
  - Returns 0 if apk is absent (non-Alpine — graceful no-op)
  - On Alpine without bash: calls `pkg_install bash` to install it
- Wired `_ensure_alpine_bash || return 1` into the entry of:
  - `install_nvm_node()` — after banner, before musl check
  - `install_bun()` — after banner, before bun check
  - `install_yarn()` — after banner, before yarn check
  - `install_opencode_gsd()` — after banner, before nvm sourcing

### fu-sh/test_fu_alpine_bash.sh (new)
- Contract test that extracts the real helper from fu.sh via sed
- 3 test cases: bash-present no-op, Alpine bash-absent triggers install, non-Alpine bash-absent no-op
- All 3 cases pass (pass=3 fail=0)

## Commits

1. `5fb0b9f` — feat(alpine): add _ensure_alpine_bash helper and wire into npm-dependent installs
2. `fdbd5e3` — test(alpine): add contract test for _ensure_alpine_bash helper

## Verification

- `bash -n fu-sh/fu.sh` — syntax OK
- `bash fu-sh/test_fu_alpine_bash.sh` — pass=3 fail=0
- `_ensure_alpine_bash` appears 5 times in non-comment lines (1 definition + 4 call sites)
- Shebang unchanged
