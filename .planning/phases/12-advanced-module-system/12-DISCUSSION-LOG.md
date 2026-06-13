# Phase 12: Advanced Module System - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-28
**Phase:** 12-advanced-module-system
**Areas discussed:** CLI flag design, Batch execution behavior, Registry architecture, Registry discovery UX

---

## CLI Flag Design

### Q1: CLI interface pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Action flags | `flu.sh --install go,rust --remove starship --yes`. Multiple action flags compose naturally. | ✓ |
| Positional subcommands | `flu.sh install go rust --yes`. More traditional CLI feel. | |
| You decide | OpenCode picks the best approach. | |

**User's choice:** Action flags (Recommended)

### Q2: --list output format

| Option | Description | Selected |
|--------|-------------|----------|
| Full module listing | Table format: category, name, action_id, installed status. Also supports --list --json. | ✓ |
| Minimal (IDs only) | Just action_ids, easy to pipe. | |
| You decide | OpenCode picks. | |

**User's choice:** Full module listing (Recommended)

### Q3: Flag scope

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal set | --install, --remove, --list, --yes only. Status/compare/version are future. | ✓ |
| Full utility set | Also --status, --compare, --version from day one. | |
| You decide | OpenCode picks. | |

**User's choice:** Minimal set (Recommended)

### Q4: Tool name format in --install/--remove

| Option | Description | Selected |
|--------|-------------|----------|
| Exact action IDs only | Users type `install_go`, `remove_rust`. Unambiguous, matches menu.db. | ✓ |
| Short names with mapping | `go` → `install_go` via prefix-matching. More ergonomic. | |
| You decide | OpenCode picks. | |

**User's choice:** Exact action IDs only

---

## Batch Execution Behavior

### Q1: Failure handling

| Option | Description | Selected |
|--------|-------------|----------|
| Continue on failure | Run all modules, collect results, print summary. Like apt upgrade. | ✓ |
| Abort on first failure | Stop immediately on first failure. Safer but incomplete. | |
| You decide | OpenCode picks. | |

**User's choice:** Continue on failure (Recommended)

### Q2: Param-requiring modules in batch mode

| Option | Description | Selected |
|--------|-------------|----------|
| Reject param-requiring modules | Clear error: "use interactive mode". Safe, simple. | ✓ |
| Use defaults | Risky — wrong defaults could break things. | |
| You decide | OpenCode picks. | |

**User's choice:** Reject param-requiring modules (Recommended)

### Q3: Batch output format

| Option | Description | Selected |
|--------|-------------|----------|
| Plain text status lines | `✓ install_go — Complete` / `✗ install_rust — Failed (exit 1)`. Final summary. | ✓ |
| JSON output | Structured for CI/CD. More parseable but adds complexity. | |
| You decide | OpenCode picks. | |

**User's choice:** Plain text status lines (Recommended)

### Q4: Exit code behavior

| Option | Description | Selected |
|--------|-------------|----------|
| 0=all pass, 1=any fail | Simple, standard, CI-friendly. | ✓ |
| Exit code = failure count | More informative but non-standard. | |
| You decide | OpenCode picks. | |

**User's choice:** 0=all pass, 1=any fail (Recommended)

---

## Registry Architecture

### Q1: Registry location and format

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub-hosted JSON index | registry.json in a GitHub repo. Each entry: action_id, name, description, platforms, base_url, sha256. | ✓ |
| Web API endpoint | More powerful but requires hosting. | |
| You decide | OpenCode picks. | |

**User's choice:** GitHub-hosted JSON index (Recommended)

### Q2: Adding third-party registries

| Option | Description | Selected |
|--------|-------------|----------|
| ENV var list | `FLU_REGISTRIES=https://...` space-separated URLs. Same pattern as FLU_MODULES_BASE_URL. | ✓ |
| Config file | ~/.config/flu.sh/registries.conf. More persistent but adds config management. | |
| You decide | OpenCode picks. | |

**User's choice:** ENV var list (Recommended)

### Q3: Trust/security model for community modules

| Option | Description | Selected |
|--------|-------------|----------|
| Same checksum model | SHA256 verification against registry index, same as official. No execution without verification. | ✓ |
| Warning + confirm only | Trust on first use. Less strict, simpler for contributors. | |
| You decide | OpenCode picks. | |

**User's choice:** Same checksum model (Recommended)

---

## Registry Discovery UX

### Q1: Community modules in TUI menu

| Option | Description | Selected |
|--------|-------------|----------|
| Menu category | New "Community Modules" top-level category with subcategory per registry. | ✓ |
| CLI-only | No menu integration. Less discoverable. | |
| You decide | OpenCode picks. | |

**User's choice:** Menu category (Recommended)

### Q2: Name conflict handling

| Option | Description | Selected |
|--------|-------------|----------|
| Namespace prefix | `community/install_neovim`. No conflict possible. Clear visual distinction. | ✓ |
| Official wins on conflict | Simpler but confusing. | |
| You decide | OpenCode picks. | |

**User's choice:** Namespace prefix (Recommended)

### Q3: Installing community modules

| Option | Description | Selected |
|--------|-------------|----------|
| Same --install with namespaced ID | `flu.sh --install community/install_neovim`. Registry provides base URL. Same pipeline. | ✓ |
| Dedicated --registry flag | More explicit but adds flags. | |
| You decide | OpenCode picks. | |

**User's choice:** Same --install with namespaced ID (Recommended)

---

## OpenCode's Discretion

- Exact CLI argument parsing implementation (getopts vs manual while/case)
- JSON parsing approach for registry index (awk/jq or simple grep/sed)
- How registry entries are cached and refreshed
- Menu.db generation for community modules (dynamic injection vs static append)
- How `--list --json` output is structured
- Error message wording and formatting details

## Deferred Ideas

None — discussion stayed within phase scope.
