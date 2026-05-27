---
phase: 11-modern-cli-tools
plan: 02
status: done
commit: dfc3435
---

## Summary

Created install/remove module scripts for zoxide and eza, added menu.db entries, updated README, and regenerated MANIFEST.

### Artifacts

| File | Description |
|------|-------------|
| `modules/install_zoxide.sh` | Downloads pre-built binary from GitHub releases, adds shell init to .bashrc/.zshrc/fish |
| `modules/remove_zoxide.sh` | Removes binary (brew on macOS, /usr/local/bin on Linux), cleans RC files, removes data dir |
| `modules/install_eza.sh` | Package manager install (apt with gierens.de repo, pacman, zypper, dnf), cargo fallback |
| `modules/remove_eza.sh` | Tries package manager + cargo uninstall, cleans up residual binaries |
| `menu.db` | 4 new entries under Modern CLI for zoxide and eza |
| `modules/README.md` | 8 new action IDs added, total corrected to 55 scripts |
| `modules/MANIFEST.sha256` | Regenerated with all 55 script checksums |

### Verification

- All 4 scripts pass shellcheck with POSIX sh mode
- MANIFEST checksums verified: `sha256sum -c --strict` passes
- menu.db has 8 Modern CLI entries (4 tools x 2 operations)
- Total script count: 55 (30 install, 17 remove, 2 display, 2 create, 2 configure, 1 set, 1 upgrade)

### Notes

- README total count was stale at 31 — corrected to actual count of 55
- eza install adds the gierens.de apt repository with GPG key for Debian/Ubuntu systems
- Both zoxide and eza installers are idempotent (check `command -v` first)
