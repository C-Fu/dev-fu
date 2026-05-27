# Phase 10: Module Pipeline Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 10-Module Pipeline Hardening
**Areas discussed:** Checksum manifest format, Cache location & strategy, Progress bar style, Logging format & storage

---

## Checksum Manifest Format

| Option | Description | Selected |
|--------|-------------|----------|
| Central manifest | One MANIFEST.sha256 in modules/ listing all checksums. Simple, grep-friendly. | ✓ |
| Per-module sidecar | Each module gets a .sha256 sidecar file. Distributed. | |

**User's choice:** Central manifest

| Option | Description | Selected |
|--------|-------------|----------|
| sha256sum format | `<sha256>  <filename>` per line — verifiable with `sha256sum -c` | ✓ |
| Extended custom format | Custom format with version, size, date fields | |

**User's choice:** sha256sum format

| Option | Description | Selected |
|--------|-------------|----------|
| Soft fail | If manifest can't be fetched, proceed without checksum (log warning) | ✓ |
| Hard fail | Block module execution if manifest unavailable | |

**User's choice:** Soft fail

---

## Cache Location & Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| XDG cache dir | `~/.cache/flu.sh/` — follows XDG standard, clearable via standard tools | ✓ |
| /tmp based | `/tmp/flu_cache/` — cleared on reboot | |
| XDG data dir | `~/.local/share/flu.sh/cache/` — data dir, not typically cleared | |

**User's choice:** XDG cache dir

| Option | Description | Selected |
|--------|-------------|----------|
| By action_id | Cache by action_id only. Invalidate via TTL. Simple. | ✓ |
| By content hash | Cache by content hash. Never stale but requires fetching first. | |

**User's choice:** By action_id

| Option | Description | Selected |
|--------|-------------|----------|
| 24 hours | Serve from cache if < 1 day old. Good balance. | ✓ |
| 7 days | More aggressive caching, fewer network calls. | |
| Configurable | FLU_CACHE_TTL env var, default 24h. | |

**User's choice:** 24 hours

---

## Progress Bar Style

| Option | Description | Selected |
|--------|-------------|----------|
| Simple percentage | `\r` overwrite: `Downloading install_go.sh... 45% (12K/26K)`. Works everywhere. | ✓ |
| Visual bar | `[████████░░░░] 45%` with bytes. Needs Content-Length. | |
| Spinner only | Dots or spinner animation. No progress data needed. | |

**User's choice:** Simple percentage

---

## Logging Format & Storage

| Option | Description | Selected |
|--------|-------------|----------|
| TSV | Tab-separated: timestamp, action_id, operation, result, version. Easy to grep/awk. | ✓ |
| JSON lines | Structured JSON. Better for tooling but heavier for pure shell. | |

**User's choice:** TSV

| Option | Description | Selected |
|--------|-------------|----------|
| XDG data dir | `~/.local/share/flu.sh/execution.log` — appropriate for persistent logs | ✓ |
| With cache dir | `~/.cache/flu.sh/execution.log` — clearable with cache | |

**User's choice:** XDG data dir

| Option | Description | Selected |
|--------|-------------|----------|
| No rotation | Append-only. Users can truncate manually. Simplest. | ✓ |
| Size-based rotation | Rotate at 1MB, keep 3 files. | |

**User's choice:** No rotation

---

## OpenCode's Discretion

- Exact curl flags for progress parsing
- Cache directory creation and permission handling
- Log file header/structure details
- Cache corruption handling (re-fetch silently)
- Integration of progress into existing `flu_module_fetch()` flow

## Deferred Ideas

None — discussion stayed within phase scope.
