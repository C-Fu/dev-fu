---
phase: 11-modern-cli-tools
plan: 01
status: done
commit: 070ef4c
---

## Summary

Created install/remove module scripts for lazygit and starship, added menu.db entries under new Modern CLI category.

### Artifacts

| File | Description |
|------|-------------|
| `modules/install_lazygit.sh` | Downloads pre-built Go binary from GitHub releases (x86_64/arm64/armv7) |
| `modules/remove_lazygit.sh` | Deletes binary and state directory |
| `modules/install_starship.sh` | Uses official installer on Linux, brew on macOS, adds shell init to .bashrc/.zshrc/fish |
| `modules/remove_starship.sh` | Removes binary (brew or /usr/local/bin), cleans RC files of starship init lines |
| `menu.db` | New Modern CLI category with 4 entries (lazygit + starship) |

### Verification

- All 4 scripts pass shellcheck with POSIX sh mode
- menu.db has 4 Modern CLI entries for lazygit and starship

### Notes

- lazygit: arch detection maps aarch64→arm64, armv7l→armv7 per release naming
- starship: uses `curl -sS https://starship.rs/install.sh | sh -s -- -y` on Linux for zero-interaction install
- Both installers are idempotent
