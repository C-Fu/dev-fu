# Project Research Summary

**Project:** dev-fu / flu.sh — lxdialog-style TUI engine
**Domain:** Cross-platform shell-script TUI menu system (POSIX sh)
**Researched:** 2026-05-23
**Confidence:** HIGH

## Executive Summary

flu.sh is a zero-dependency, curl-pipe-bash shell script that embeds a portable TUI engine and hierarchical menu system for developer environment setup. It must render interactive menus using only `printf` (ANSI escape sequences), read keystrokes via `dd bs=1 </dev/tty`, and control terminal mode with `stty` — all in strict POSIX sh that runs on dash, ash, BusyBox, and bash alike. The existing `checklist.sh` (596 lines) already proves this approach works; the new engine extends it with additional widget types, nested submenus, and a module execution system.

The recommended architecture is a single-file, 5-layer design: (1) Utility & Platform Detection, (2) TUI Engine (terminal primitives → drawing primitives → widgets), (3) Menu System (registry, navigation stack, prompt system), (4) Module Execution (fetch, cache, validate, exec), and (5) Main Orchestrator. Everything lives in one file because the deployment constraint demands curl-pipe-bash with zero local files. Modules are the only external component, fetched on-demand from GitHub and executed in subshells for isolation.

The dominant risk is POSIX portability. The existing codebase already contains bashisms (`$'\033'`, GNU `sed` patterns) that silently break on dash/ash. Every line of the TUI engine must be tested against ShellCheck with `# shellcheck shell=sh` and verified on dash, BusyBox ash, and Alpine. The second risk is terminal state corruption on crashes — if `term_restore()` is not called on every exit path, users get a broken terminal. Defensive multi-signal traps at the outermost level are non-negotiable.

## Key Findings

### Recommended Stack

The entire TUI is built on three POSIX tools: `printf` for rendering, `dd` for key input, and `stty` for terminal mode control. No external TUI libraries (dialog, whiptail, ncurses, gum) are used or expected. The engine uses full redraw on each keypress — simpler, more reliable, and fast enough for <100 item menus.

**Core technologies:**
- `printf` + ANSI escape sequences — all rendering; works on every terminal since VT100
- `dd bs=1 count=1 </dev/tty` — single-byte key reads; only POSIX-portable approach
- `stty -echo -icanon` + `stty -g` save/restore — raw terminal mode; universal
- `tput lines/cols` with fallback to `$COLUMNS/$LINES` → 80×24 — terminal size detection
- `\033[7m` (reverse video) — primary selection highlight; works on every terminal including monochrome
- ASCII box drawing (`+`, `-`, `|`) — universal; Unicode box drawing is optional enhancement
- `awk -F'|'` — parsing menu definitions; no jq/yq dependency
- `eval "var_$idx=value"` — simulated arrays in POSIX sh; proven in existing checklist.sh

**Critical version constraints:**
- Must work on dash (Debian/Ubuntu `/bin/sh`), BusyBox ash (Alpine), bash, zsh
- POSIX.1-2001 baseline; do NOT rely on POSIX.1-2024 additions
- ShellCheck with `-s sh` must pass cleanly on all TUI engine code

### Expected Features

**Must have (table stakes) — blocks MVP:**
- Arrow key + j/k navigation, Enter/Esc/q — universal TUI muscle memory
- Reverse-video cursor highlight, scroll indicators (↑more/↓more)
- Pagination (PgUp/PgDn), Home/End jump, number shortcuts (type "5" → item 5)
- Dumb-terminal fallback (numbered prompt) for CI, pipes, TERM=dumb
- TTY reattachment for curl-pipe-bash (`exec 0</dev/tty`)
- Breadcrumb trail + back navigation (Esc/Left) in nested submenus (3 levels max)
- Inline yes/no confirmation before destructive operations
- Consistent help footer on every screen
- Select All / Deselect All toggle on checklists

**Should have (competitive differentiation):**
- Substring search/filter (type to narrow list) — #1 UX differentiator vs numbered menus
- Radio-button single-select widget — needed for inline variable prompts
- Inline text input widget — for module parameter collection
- Module registry with auto-discovery (manifest fetch from GitHub)
- Module script contract (shebang + metadata comments)
- Color themes via env var (`FLU_THEME=dracula`)
- Unicode box drawing with ASCII auto-fallback
- Batch mode / CLI passthrough (`flu.sh --install python --global`)
- Spinner during network operations
- Checksum verification for remote scripts

**Defer (v2+):**
- Progress bar (spinner is sufficient for MVP)
- Contextual description panel
- Operation logging
- Mouse support
- Fuzzy search
- Configuration file / state persistence

### Architecture Approach

Single-file, 5-layer architecture with strict dependency ordering. Functions are defined bottom-up (utility → TUI engine → menu system → modules → orchestrator). Widgets follow the gum/fzf contract: positional args in, selection on stdout, exit code 0=confirm / 1=cancel. Menu definitions use a pipe-delimited DSL parsed with `awk` into eval-based indexed variables — the only POSIX-portable way to simulate arrays. Modules execute in subshells receiving environment variables (`FLU_OS`, `FLU_DISTRO`, `FLU_PKG_MGR`, etc.) and returning exit codes.

**Major components:**
1. **TUI Engine** (terminal prims → drawing prims → widgets) — the foundation; `term_init`/`term_restore`, `read_key`, `draw_box`, `menu_single`, `checklist`, `yesno`, `inputbox`
2. **Menu System** (registry + navigation + prompts) — pipe-delimited menu DSL, stack-based submenu push/pop, breadcrumb tracking, prompt collection before module execution
3. **Module Execution** (fetch + cache + validate + exec) — curl/wget fetch from GitHub raw, cache in `~/.cache/flu.sh/modules/`, age-based invalidation (24h), subshell execution with env var contract
4. **Main Orchestrator** — CLI arg parsing, TTY reattach, platform detection, main loop, error handling

**Key patterns:**
- Widget interface: `selected=$(menu_single "Title" "Prompt" "tag1|Label 1" "tag2|Label 2")` → stdout + exit code
- Fallback chain: best option first, degrade gracefully (curl → wget → error; tput → `$COLUMNS` → 80)
- Eval-based arrays: `eval "item_tag_$idx=value"` — only POSIX way; sanitize all inputs
- Menu stack: colon-separated string `"main:install:lang"`, push/pop with awk

### Critical Pitfalls

1. **`$'\033'` is not POSIX** — All key matching and ANSI rendering breaks on dash/ash. Use `ESC=$(printf '\033')` once, then `"$ESC[A"`. The existing checklist.sh has this bug on every key comparison line (91-93, 302-368). **Must fix in Phase 1.**

2. **`echo -e` / `echo -n` is not POSIX** — In dash, `echo -e "foo"` prints `-e foo` literally. Use `printf` for ALL output that needs escape sequences or suppresses newlines. Coding standard from day one.

3. **Terminal state corruption on crash** — If `term_restore()` is missed on ANY exit path (error, signal, set -e), the user's terminal is left in raw mode with no echo. Register multi-signal trap (`INT TERM HUP QUIT`) at the outermost level, not inside nested functions.

4. **GNU sed `\x1b` not portable** — The `str_len()` function's ANSI-stripping sed pattern breaks on macOS BSD sed and BusyBox sed. Use `$(printf '\033')` inside sed or switch to `awk` for ANSI stripping.

5. **Multi-byte escape sequence timing over SSH** — Arrow keys send 3 bytes (`ESC [ A`); `dd bs=1 count=2` assumes all bytes arrive instantly. Over high-latency SSH, bytes may arrive in separate packets. Use `stty min 0 time 2` (200ms timeout) when reading sequence continuation bytes.

## Implications for Roadmap

### Phase 1: Terminal Primitives + Drawing
**Rationale:** Everything depends on correct TTY control and rendering. The existing checklist.sh has known bashisms that must be fixed here. This is the critical gate.
**Delivers:** `term_init`, `term_restore`, `read_key`, `move_cursor`, `clear_screen`, `draw_box`, `draw_title`, `truncate_text`, `print_centered`
**Addresses:** Arrow nav, reverse-video highlight, scroll indicators
**Avoids:** Pitfalls #1 ($'\033'), #2 (read -n), #4 (echo -e), #5 (sed \x1b), #6 (terminal corruption)
**Test:** Key-echo demo under dash and busybox sh; Ctrl-C must restore terminal

### Phase 2: Single-Select Menu Widget
**Rationale:** The single-select menu is the critical-path widget — all interactive flows depend on it. It validates the TUI engine end-to-end.
**Delivers:** `menu_single(title, prompt, items...) → tag on stdout`, with arrow keys, j/k, Enter/Esc, Home/End, PgUp/PgDn, number shortcuts, scroll indicators, help footer
**Uses:** All Phase 1 primitives
**Implements:** The core interactive widget pattern that other widgets follow
**Avoids:** Pitfall #7 (redraw flicker) via buffered output
**Test:** Interactive 20-item menu; navigate with all key types; cancel with Esc

### Phase 3: Additional Widgets
**Rationale:** With the menu widget pattern proven, additional widgets follow the same contract. The checklist already exists in checklist.sh — adapt, don't rewrite.
**Delivers:** `checklist()` (adapted from existing), `yesno()`, `inputbox()`, `radiolist()`, dumb-terminal fallback for each
**Uses:** Phase 1 drawing primitives
**Implements:** Widget interface contract (stdout + exit code)
**Test:** Each widget standalone; dumb-terminal fallback via `TERM=dumb`

### Phase 4: Menu Definition Parser + Navigation
**Rationale:** With widgets working, the menu system provides the hierarchical structure. This can be developed in parallel with Phase 3.
**Delivers:** `_parse_menu_defs`, `_menu_children`, `_menu_lookup`, navigation stack (push/pop), breadcrumb display, back navigation
**Implements:** Pipe-delimited menu DSL, eval-based indexed storage, colon-separated nav stack
**Test:** Load 50-item definition; navigate main → install → lang → back → back; verify breadcrumbs

### Phase 5: Module Fetcher + Executor
**Rationale:** Independent of TUI — can be developed in parallel with Phases 2-4. Modules execute in subshells so they never touch the TUI engine.
**Delivers:** `fetch_module`, `validate_module`, `exec_module`, cache management, curl/wget fallback, error handling with retry
**Implements:** Module interface contract (env vars in, exit code out), age-based cache invalidation
**Avoids:** Pitfall #11 (curl|sh security) via HTTPS + commit SHA pinning
**Test:** Fetch and execute a sample module; verify cache hit on second run; test with no network

### Phase 6: Main Orchestrator + Integration
**Rationale:** Wires everything together. CLI arg parsing, TTY reattach, platform detection, the main interactive loop, and the module result display flow.
**Delivers:** CLI mode (`flu.sh --install docker`), interactive main loop, prompt system (`ask_choice`, `ask_text`, `ask_confirm`), error display, "Press any key" flow
**Implements:** Full E2E flow: start → navigate → select → collect params → execute module → show result
**Test:** Full walkthrough in bash, dash, and busybox sh; CLI mode; Ctrl-C safety

### Phase 7: Polish & Edge Cases
**Rationale:** Make it production-ready. Resize handling, signal robustness, Alpine/Termux/WSL testing, spinner, color themes, Unicode box drawing fallback.
**Delivers:** SIGWINCH resize handling, color themes, Unicode detection, ASCII art fallback, spinner, batch mode CLI passthrough
**Avoids:** Pitfalls #9 (resize), #10 (tput unavailable), #17 (tmux/screen)
**Test:** Run inside `docker run --rm -it alpine sh`; resize terminal; run inside tmux

### Phase Ordering Rationale

- Phase 1 is the hard gate — if terminal primitives don't work portably, nothing works. Get this right and everything else follows.
- Phases 2, 4, and 5 can be parallelized after Phase 1: widgets, menu data, and module execution have zero dependencies on each other.
- The critical path is Phase 1 → Phase 2 → Phase 6 (orchestrator needs the menu widget).
- Phase 3 (additional widgets) and Phase 4 (menu parser) feed into Phase 6 independently.
- Phase 7 is last because it requires all components to be stable before adding polish.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 5 (Module Execution):** Security model for remote script execution — SHA256 checksum workflow, commit SHA pinning vs branch ref, trust boundaries
- **Phase 6 (Main Orchestrator):** Prompt system design for module parameter collection — how modules declare their required prompts, validation, and the handoff protocol
- **Phase 7 (Polish):** SIGWINCH handling across dash/ash/busybox — POSIX support varies; needs empirical testing, not documentation research

Phases with standard patterns (skip deep research):
- **Phase 1 (Terminal Primitives):** Well-documented ANSI sequences, proven in existing checklist.sh
- **Phase 2 (Menu Widget):** lxdialog's menubox.c is the canonical reference; existing checklist.sh validates the approach
- **Phase 3 (Widgets):** gum's command-per-widget pattern is well-understood; each widget is a self-contained function

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Verified against ECMA-48, ncurses terminfo, VT100 reference, and existing working checklist.sh. All three core tools (printf, dd, stty) proven across target shells. |
| Features | HIGH | Feature expectations sourced from gum, fzf, lxdialog, oh-my-zsh, bash-it, and existing codebase. MVP scope is clear and well-bounded by anti-features list. |
| Architecture | HIGH | 5-layer single-file design validated against lxdialog (layered primitives), gum (widget contract), fzf (pipeline model), and existing checklist.sh (proven patterns). |
| Pitfalls | HIGH | All pitfalls verified against ShellCheck wiki, Wooledge bashism docs, Ubuntu DashAsBinSh, and ncurses FAQ. Existing codebase issues identified concretely with line numbers. |

**Overall confidence:** HIGH

### Gaps to Address

- **Escape sequence timing over SSH:** The `dd`-based key reading approach has known timing issues over high-latency connections. The `stty min 0 time N` inter-byte timeout is the documented fix but needs empirical validation across dash/ash/busybox during Phase 1 implementation.
- **PowerShell TUI implementation:** Research identified that PowerShell 5.1 doesn't support ANSI escape sequences natively. The PowerShell port needs a completely separate TUI implementation. This is out of scope for the POSIX sh roadmap but must not be forgotten if cross-platform coverage is required.
- **Scroll region for large lists:** The `\033[top;bottomr` escape sequence is marked as essential for scrollable menu content areas but portability across minimal terminals needs testing during Phase 2.
- **Number shortcut accumulator:** Multi-digit number input (type "12" to jump to item 12) requires a key accumulator pattern not present in checklist.sh. Implementation needs careful timeout design to distinguish "user pressed 1 then 2" from "user pressed 1 then paused then pressed 2".

## Sources

### Primary (HIGH confidence)
- ECMA-48 standard — all CSI escape sequences, cursor movement, SGR attributes
- ncurses terminfo.src (invisible-island.net) — terminfo capabilities, actual escape sequences per terminal type
- VT100 User Guide (vt100.net) — escape sequence origins, cursor key codes
- Linux kernel lxdialog (torvalds/linux) — widget-primitive pattern, menu widget architecture, scroll handling
- charmbracelet/gum — command-per-widget architecture, pipeline philosophy, UX patterns
- junegunn/fzf — stdin/stdout pipeline model, multi-select UX
- Existing checklist.sh (596 lines) — proven POSIX TUI patterns, dd key reads, stty raw mode, ANSI rendering
- Existing fu.sh (2,629 lines) — menu structure, platform detection, module dispatch
- ShellCheck wiki — POSIX sh conformance requirements (SC2039, SC3003, SC3037, SC3045)

### Secondary (MEDIUM confidence)
- ohmyzsh/ohmyzsh — plugin loading, convention-based architecture
- bash-it/bash-it — module load priority, file naming conventions
- grub2-themes install.sh — real-world curl|sh installer with TTY handling
- Wooledge Bashism page — POSIX incompatibility catalog
- Ubuntu DashAsBinSh — dash-specific behavior documentation

---
*Research completed: 2026-05-23*
*Ready for roadmap: yes*
