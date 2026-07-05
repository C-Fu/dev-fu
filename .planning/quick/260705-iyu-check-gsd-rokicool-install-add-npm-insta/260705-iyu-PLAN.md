---
id: 260705-iyu
slug: check-gsd-rokicool-install-add-npm-insta
date: 2026-07-05
status: completed
---

# Quick Task: Check GSD Rokicool install, add gsd-sdk PATH setup, compile fust, push release

## Tasks

1. **Modify `install_gsd_rokicool.sh`** — Add `_ensure_gsd_sdk_on_path` helper that symlinks `gsd-sdk` from npm global prefix to `~/.local/bin/` after installing `gsd-opencode`.
   - Files: `flu-sh/modules/install_gsd_rokicool.sh`
   - Action: Edit install script to verify `gsd-sdk` is on PATH post-install; if not, symlink from npm global bin dir
   - Verify: `command -v gsd-sdk` works post-install

2. **Modify `install_opencode_gsd.sh`** — Add gsd-sdk PATH setup after GSD install section.
   - Files: `flu-sh/modules/install_opencode_gsd.sh`
   - Action: Add gsd-sdk symlink logic after GSD Rokicool install block
   - Verify: Syntax check passes with `sh -n`

3. **Rebuild fust binary** — Bump version and compile release binary.
   - Files: `fust/Cargo.toml`, `fust/Cargo.lock`
   - Action: Bump `3.0.0-alpha.13` → `3.0.0-alpha.14`, run `cargo build --release`
   - Verify: `fust --version` outputs `3.0.0-alpha.14`

4. **Push new git release** — Commit, tag, push.
   - Action: `git add`, `git commit`, `git tag v3.0.0-alpha.14`, `git push origin main --tags`
   - Verify: Tag exists on remote
