---
id: 260705-iyu
slug: check-gsd-rokicool-install-add-npm-insta
date: 2026-07-05
status: complete
commit: 4d8d11b
tag: v3.0.0-alpha.14
---

# Quick Task Summary: GSD Rokicool gsd-sdk PATH + fust release

## What was done

1. **`flu-sh/modules/install_gsd_rokicool.sh`** — Added `_ensure_gsd_sdk_on_path` helper function. After `npm install -g gsd-opencode`, the script now:
   - Verifies `gsd-sdk` is in PATH
   - If not found, locates it from `npm prefix -g` and symlinks to `~/.local/bin/`
   - Warns if `~/.local/bin/` is not in PATH

2. **`flu-sh/modules/install_opencode_gsd.sh`** — Added gsd-sdk PATH setup block after GSD Rokicool install section. Same symlink + PATH warning logic.

3. **`fust` v3.0.0-alpha.14** — Bumped version, rebuilt release binary.

4. **Release** — Committed as `4d8d11b`, tagged `v3.0.0-alpha.14`, pushed to `origin/main`.

## Key decisions

- `gsd-sdk` is bundled with `gsd-opencode` (it's a binary entry in the npm package). No separate `gsd-sdk` npm package exists.
- The fix symlinks from npm global prefix bin dir to `~/.local/bin/` (which is first in PATH on this system).
- Both `install_gsd_rokicool.sh` and `install_opencode_gsd.sh` updated for consistency.
