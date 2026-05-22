# Feature Landscape

**Domain:** Portable shell-script TUI menu system (lxdialog-style)
**Researched:** 2026-05-23
**Parent project:** dev-fu / flu.sh

## Context

This document covers features for the **new modular TUI system** (`flu.sh`), not the existing flat menu in `fu.sh`. The existing `checklist.sh` (596 lines POSIX sh) already implements a multi-select checklist widget with arrow keys, WASD, pagination, select-all, and dumb-terminal fallback. The new system builds on that foundation to create a full lxdialog-style TUI engine with nested menus, module loading, and inline prompts.

Sources for feature expectations: gum (charmbracelet/gum), fzf (junegunn/fzf), Linux kernel lxdialog (torvalds/linux), oh-my-zsh plugin architecture, bash-it module system, and the existing `checklist.sh` implementation.

---

## Table Stakes

Features users expect. Missing = product feels incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Arrow key navigation (Up/Down)** | Every TUI since 1993. lxdialog has it, gum has it, fzf has it. | Low | checklist.sh already has this. Extend to menu/list widgets. |
| **Enter to select, Esc/q to cancel** | Universal muscle memory. Non-negotiable. | Low | checklist.sh has this. Must be consistent across all widgets. |
| **Reverse-video highlight on cursor row** | Standard cursor indication in every terminal menu. lxdialog uses `wattrset(selected)`, gum uses Lip Gloss styling. | Low | checklist.sh uses `\033[7m` (reverse video). Keep this pattern. |
| **Scroll indicators (more items above/below)** | Users must know the list continues. lxdialog has `print_arrows()` with up/down arrows. | Low | Show `↑ more` / `↓ more` or `(+)` / `(-)` at edges when content overflows. |
| **Pagination (PgUp/PgDn)** | Essential for lists >20 items. lxdialog has KEY_PPAGE/KEY_NPAGE. checklist.sh has it. | Low | Already in checklist.sh. Port to menu widget. |
| **Dumb-terminal fallback (numbered prompt)** | SSH into minimal containers, CI, cron — TERM=dumb must work. | Low | checklist.sh has `checklist_fallback()`. Every widget needs a fallback variant. |
| **TTY reattachment for curl\|bash** | Project identity is curl-pipe-bash. Without this, the install method breaks. | Low | fu.sh already does `exec 0</dev/tty`. Must carry forward. |
| **Home/End keys (jump to first/last item)** | Standard in every list UI. gum, fzf, lxdialog all support it. | Low | Escape sequences: `\033[H` / `\033[F` and `\033[1~` / `\033[4~` variants. |
| **Vi keys (j/k for down/up)** | Developer audience expects vi keys. fzf supports CTRL-J/CTRL-K. | Low | Add `j`/`k` alongside arrow/WASD in all navigation widgets. |
| **Number shortcuts (type "5" to jump to item 5)** | The existing fu.sh flat menu is numbered. Users will type numbers by habit. | Med | Requires key accumulator: detect digit keys, build number, jump to item. Must handle items > 9 (multi-digit). |
| **Breadcrumb trail in nested menus** | Users get lost in 3-level deep submenus. "Main > Languages > Python" at top of screen. | Med | Simple string concatenation per nesting level. Display in title bar. |
| **Back/Return from submenu** | Universal: Esc or Left arrow returns to parent menu. | Low | Stack-based menu depth tracking. Pop on back, push on descend. |
| **[x]/[ ] checkbox rendering** | Visual indicator of selection state. checklist.sh has it. | Low | Already implemented. |
| **Select All / Deselect All toggle** | checklist.sh has `A` key toggle-all. Standard in multi-select UIs. | Low | Already implemented. |
| **Inline yes/no confirmation before destructive ops** | "Remove Docker? [y/N]" — gum confirm, lxdialog yesno. Users expect a safety net. | Low | Simple `read -r` with y/N parsing. No fancy widget needed for MVP. |
| **Spinner/progress during network operations** | Fetching remote modules over network can stall. Users need feedback. | Med | Rotating ASCII spinner `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` or simple `-\\|/` on a single line. |
| **Clear error messages with recovery hints** | "Failed to fetch module: network error. Retry? [Y/n]" — not just exit 1. | Med | Structured error function with suggestion. |
| **Consistent help footer** | checklist.sh shows key hints at bottom. Every screen needs contextual help. | Low | One-line footer: `↑↓ Navigate  Enter Select  Esc Back  ? Help` |
| **Terminal resize handling** | `SIGWINCH` — lxdialog has `KEY_RESIZE` with `goto do_resize`. | Med | Trap SIGWINCH, re-query `tput lines/cols`, re-render. POSIX trap support varies. |
| **Shell compatibility (bash, zsh, dash, ash, busybox sh)** | Explicit project requirement. Must work on Alpine (ash), Ubuntu (dash). | High | All core widget code must avoid Bash-isms. Use ShellCheck with `# shellcheck shell=sh`. |

## Differentiators

Features that set the product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **In-menu search/filter (type to narrow list)** | fzf/gum-filter UX for large menus. Type "py" to jump to Python options. This is the #1 UX differentiator vs numbered menus. | High | Requires: text input buffer overlay, substring match against labels, real-time list narrowing. Complex in POSIX sh (no arrays). Consider: show only matching items, re-index cursor. |
| **Radio-button single-select widget** | "Install scope: ( ) Global (•) Local" — like lxdialog radiolist. Distinct from multi-select checklist. | Med | New widget: render `(•)` / `(○)`, single selection only. Needed for inline variable prompts (PROJECT.md requirement). |
| **Inline text input widget** | "Enter version:" with cursor, backspace, max-length — like gum input. Needed for variable passing to modules. | Med | Raw mode already works (stty -echo -icanon). Need: character buffer, cursor display, backspace handling, max-length, validation. Must work without Bash `read -e`. |
| **Module registry with auto-discovery** | `flu.sh` fetches a manifest/module-index from GitHub raw, presents all available modules without hardcoding. New modules appear without flu.sh changes. | Med | A single `modules.tsv` file on GitHub: `tag|label|category|script_url`. flu.sh fetches and parses it. Modules self-describe. |
| **Module script contract (shebang + metadata)** | Each module script declares: required-args, supported-platforms, description via structured comments. flu.sh validates before execution. | Low | Convention: module scripts start with `# MODULE: install_python` `# ARGS: --global\|--local` `# PLATFORMS: linux,darwin,wsl` — flu.sh parses these. |
| **Remote module caching with TTL** | Cache fetched scripts in `/tmp/flu.sh-cache/` with expiry (e.g., 1 hour). Avoids re-downloading on repeated runs. | Med | Cache key = script URL hash. Store with timestamp. Check age before fetch. `mkdir -p /tmp/flu.sh-cache` and file-per-module. |
| **Checksum verification for remote scripts** | `sha256sum` manifest alongside modules. Verify before `sh` execution. Addresses curl\|sh security concerns. | Med | Ship a `checksums.sha256` file. flu.sh fetches script + checksums, verifies. Falls back gracefully if sha256sum unavailable. |
| **Color theme support** | "Dracula", "Solarized", "Monokai" color presets. Users can set `FLU_THEME=dracula`. | Low | Define 4-5 ANSI color presets. Read `$FLU_THEME` env var. Map to the existing color variables pattern from fu.sh. |
| **Box-drawing characters with ASCII fallback** | Use Unicode box-drawing (`┌─┐│└┘`) when terminal supports it, fall back to ASCII (`+--+||++`) when not. | Med | Detect Unicode support via `${LANG:-}` containing UTF-8 or `\033%c` test. fu.sh already uses Unicode box-drawing. |
| **Operation status column (installed/available/updateable)** | Show `[installed v3.12]` / `[available]` / `[update → v3.13]` next to menu items. Like a package manager. | Med | Requires status-check function per module. Can be slow (network calls). Consider: async pre-check, cached status, or status-on-demand (check when cursor lands on item). |
| **Batch mode / CLI passthrough** | `flu.sh --install python --global` — non-interactive execution for scripting. fu.sh already has `bash fu.sh 5 -9`. | Med | Parse CLI args, map to module + args, execute without TUI. Must coexist with interactive mode. |
| **Module execution logging** | Log module output to `/tmp/flu.sh.log` with timestamps. Users can review what happened. | Low | `exec >> /tmp/flu.sh.log 2>&1` during module execution. Date-stamped entries. |
| **Progress bar (not just spinner)** | `[████████░░░░] 60% Installing Python...` for known-length operations (download progress). | Med | Requires knowing total size. Use `\r` carriage return to overwrite line. Block character `█` / `░`. |
| **Contextual description panel** | When cursor is on an item, show a 2-3 line description below the menu. Like lxdialog's prompt text. | Low | Reserve 2-3 lines below menu list. Update on cursor move. Content comes from module metadata. |

## Anti-Features

Features to explicitly NOT build. These are traps that add complexity without proportional value.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Full fuzzy search engine** | fzf is 50K+ lines of Go. Implementing fuzzy matching in POSIX sh is pathological. Even gum delegates to a Go library. Performance on large lists in sh will be terrible. | Implement **substring filter** (exact match, case-insensitive) — 20 lines of sh. Good enough for <50 menu items. If user wants fuzzy, pipe to fzf. |
| **Mouse support** | Terminal mouse support is inconsistent across terminals, SSH, screen/tmux. lxdialog doesn't support it. Adds enormous escape-sequence complexity. | Keyboard-only navigation. This is the Unix way. The existing `fu.sh` option 14 *disables* mouse reporting — that's a hint about the project's philosophy. |
| **Configuration file / state persistence** | Explicitly out of scope in PROJECT.md. Adds file format parsing, migration, state management complexity. | Stateless design. Every run is fresh. CLI args for non-interactive control. Env vars for customization (`FLU_THEME`, `FLU_CACHE_TTL`). |
| **Plugin hot-reload / filesystem watcher** | Over-engineering for a setup utility. Not a long-running daemon. | Modules are fetched on demand per invocation. Simpler, stateless, always up-to-date. |
| **Internationalization (i18n)** | Out of scope per PROJECT.md. Terminal i18n is a nightmare (CJK width, RTL, Unicode rendering variations). | English-only labels. Module authors can put whatever they want in their scripts. |
| **Embedded TUI compositor / window manager** | Multiple simultaneous widgets, split panes, resizable regions — this is ncurses territory. We're doing pure ANSI. | Sequential, full-screen widgets. One widget visible at a time. Stack-based flow: menu → submenu → prompt → back. |
| **Auto-update mechanism for flu.sh itself** | Explicitly out of scope. Adds trust questions (who signs the update?). | User does `curl \| bash` again, or `git pull`. Manual and intentional. |
| **Interactive dependency resolution** | "Python requires libffi — install that first?" — turns into a package manager. | Modules document dependencies in metadata. Modules handle their own deps internally (like existing fu.sh install functions do). |
| **GUI / web interface** | Terminal-only identity. Out of scope. | Invest in making the TUI polished instead. |
| **Complex input validation widgets** | Date pickers, file browsers, dropdowns — way beyond the scope. | Simple text input with regex validation. Confirm prompts. Yes/No. Radio buttons. That's the set. |

---

## Feature Dependencies

```
Navigation primitives (arrows, enter, esc)
  └─→ Menu widget (single-select list)
       └─→ Nested submenu system (stack-based depth)
            └─→ Breadcrumb trail
            └─→ Back/Return navigation
       └─→ Checklist widget (multi-select, [x]/[ ])
            └─→ Select All / Deselect All
       └─→ Radio widget (single-select, (•)/(○))
            └─→ Inline variable prompts

Number shortcuts
  └─→ Key accumulator (multi-digit input)
       └─→ Menu widget

Inline text input widget
  └─→ Raw mode terminal handling (already in checklist.sh)
       └─→ Search/filter (text input + list narrowing)
            └─→ Menu widget with filtered items

Module registry (manifest fetch + parse)
  └─→ Module script contract (metadata parsing)
       └─→ Remote script fetch (curl/wget)
            └─→ Checksum verification
            └─→ Caching with TTL
       └─→ Inline prompts (module declares required args → flu.sh prompts)

Spinner / Progress bar
  └─→ Background process monitoring
       └─→ Module execution with feedback

Terminal resize (SIGWINCH)
  └─→ All widgets must re-render

Batch mode (CLI passthrough)
  └─→ Module registry (resolve module name → script URL)
       └─→ Module script contract (resolve required args)

Dumb-terminal fallback
  └─→ Every interactive widget needs a non-TTY variant

Color themes
  └─→ All widgets use color abstraction (not hardcoded ANSI)
```

---

## MVP Recommendation

**Priority order — what to build first:**

### Tier 1: Core TUI Engine (blocks everything else)
1. **Terminal primitives** — `term_init`, `term_restore`, `read_key`, `move_cursor`, `clear_screen` (extract from checklist.sh, generalize)
2. **Menu widget** — single-select list with arrow keys, j/k, enter, esc, number shortcuts, scroll indicators, home/end
3. **Dumb-terminal fallback** for menu widget
4. **Terminal resize handling** (SIGWINCH trap)

### Tier 2: TUI Completeness (makes it usable)
5. **Checklist widget** — port checklist.sh into the new engine framework (already 90% done)
6. **Radio-button widget** — needed for inline prompts
7. **Nested submenu system** — stack-based, 3 levels max, breadcrumbs, back navigation
8. **Inline text input widget** — for variable prompts
9. **Inline yes/no confirmation** — simple, but needed for destructive ops

### Tier 3: Module System (makes it modular)
10. **Module registry manifest** — fetch and parse module list
11. **Remote script fetch** — curl/wget with error handling
12. **Module script contract** — metadata convention, validation
13. **Spinner/progress** — feedback during fetch + execution

### Tier 4: Polish (makes it delightful)
14. **Substring search/filter** — type-to-narrow in menus
15. **Color themes** — env-var-driven presets
16. **Box-drawing with ASCII fallback** — Unicode detection
17. **Checksum verification** — security
18. **Caching** — performance on repeated runs
19. **Status column** — installed/available indicators
20. **Batch mode** — non-interactive CLI

### Defer until explicitly requested:
- Progress bar (spinner is sufficient for MVP)
- Contextual description panel
- Operation logging

---

## Key Insights from Research

### What gum gets right (and we should emulate in pure sh)
- **Command-per-widget pattern**: `gum choose`, `gum confirm`, `gum input`, `gum filter` — each widget is a self-contained function. flu.sh should do the same: `tui_menu()`, `tui_checklist()`, `tui_radio()`, `tui_input()`, `tui_confirm()`.
- **Stdout for output, exit code for result**: All gum widgets print selection to stdout, exit 0 for confirm, exit 1 for cancel. This is the right contract.
- **Header + footer**: gum uses `--header` for context, implicit key hints. Our footer bar should be consistent.

### What lxdialog gets right (the gold standard for this project)
- **Scroll position memory**: lxdialog saves scroll position in a temp file so returning to a submenu restores position. This is a subtle but important UX detail.
- **Hotkey navigation**: lxdialog jumps to items by first alpha character. Number shortcuts are our equivalent.
- **Button bar**: lxdialog has "Select / Exit / Help / Save / Load" — we should have "Enter=Select  Esc=Back  ?=Help" consistently.
- **Resize handling**: lxdialog does `goto do_resize` on KEY_RESIZE — we need the POSIX sh equivalent.

### What oh-my-zsh / bash-it teach us about module architecture
- **Convention over configuration**: oh-my-zsh plugins are `<name>/<name>.plugin.zsh`. Our modules should be `modules/<name>.sh` with a standard header.
- **Simple enable/disable**: bash-it uses symlinks in an `enabled/` directory. For flu.sh, we don't need enable/disable — all modules are available. The manifest IS the registry.
- **Load order matters**: bash-it uses `BASH_IT_LOAD_PRIORITY` prefixes. Our modules don't need ordering (they're executed independently, not sourced into a shared environment).
- **$ZSH_CUSTOM override path**: oh-my-zsh lets users override internals. For flu.sh, env var overrides (`FLU_THEME`, `FLU_MODULE_URL`) serve this purpose.

### curl\|sh safety (what the ecosystem actually does)
- **Checksums are the standard**: Homebrew, Nix, and most installers ship SHA256 checksums alongside scripts. This is the right approach.
- **HTTPS is the baseline**: All modern curl\|sh installers use HTTPS. GitHub raw URLs are HTTPS. This is already covered.
- **No one does GPG signing of shell scripts in practice**: While theoretically superior, GPG verification adds a dependency (gpg binary) and UX complexity. Checksums verified over HTTPS is the pragmatic choice.
- **Cache-Control headers**: The existing fu.sh already uses `Cache-Control: no-cache` in its curl command. Good practice.

---

## Sources

| Source | What It Informed | Confidence |
|--------|-----------------|------------|
| charmbracelet/gum (Context7) | Widget types, UX patterns (choose, confirm, input, filter, spin, style) | HIGH |
| junegunn/fzf (Context7) | Fuzzy search patterns, multi-select UX, key bindings | HIGH |
| torvalds/linux lxdialog (GitHub) | Menu widget architecture, scroll handling, resize, hotkeys | HIGH |
| ohmyzsh/ohmyzsh (Context7 + GitHub Wiki) | Plugin loading, customization, convention-based architecture | HIGH |
| bash-it/bash-it (Context7) | Module load priority, file naming conventions | HIGH |
| Existing checklist.sh (local codebase) | Current POSIX TUI implementation, baseline capabilities | HIGH (source code) |
| Existing fu.sh (local codebase) | Current menu structure, UX patterns, constraints | HIGH (source code) |
| grub2-themes install.sh (GitHub) | Real-world curl\|sh installer with TTY handling | MEDIUM |
| ShellCheck (Context7) | POSIX compliance requirements, common shell pitfalls | HIGH |
