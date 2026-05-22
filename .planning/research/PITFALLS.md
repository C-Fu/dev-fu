# Domain Pitfalls: Portable Shell-Script TUI Development

**Domain:** Cross-platform shell-script TUI menu system (POSIX sh + PowerShell)
**Researched:** 2026-05-23
**Confidence:** HIGH (verified against ShellCheck wiki, Wooledge bashism docs, Ubuntu DashAsBinSh, ncurses/terminfo database, existing codebase analysis)

---

## Critical Pitfalls

Mistakes that cause rewrites, silent data corruption, or broken UX on target shells.

### Pitfall 1: `$'\033'` C-Style Escape Strings — Not POSIX

**What goes wrong:** The current `checklist.sh` uses `$'\033'` and `$'\x7f'` extensively (lines 91, 92, 93, 302–368). These are **bash/ksh/zsh extensions** — they silently produce incorrect results or syntax errors in dash and busybox sh. The POSIX standard does not define `$'...'` (though POSIX.1-2024 finally added it, dash and busybox still don't support it as of 2026).

**Why it happens:** Developers test in bash (often the login shell), where `$'\033'` works perfectly. The script runs fine until someone runs it under `sh` on Ubuntu/Debian where `/bin/sh → dash`.

**Consequences:** All key matching in the TUI breaks — arrow keys, Escape, Enter, Backspace produce no response or wrong behavior. The menu becomes completely unusable.

**Prevention:**
- Use `$(printf '\033')` to build escape characters portably
- Assign to a variable once: `ESC=$(printf '\033')` then use `"$ESC[A"` instead of `$'\033[A'`
- Test under `dash` and `busybox sh` explicitly in CI
- ShellCheck flag: **SC2039** / **SC3003** (`$'...'` is undefined in POSIX sh)

**Detection:**
```bash
# Run shellcheck with POSIX target
shellcheck -s sh checklist.sh
# Quick grep for the pattern
grep -n "\\$'" checklist.sh
```

**Phase:** Must be addressed in the TUI engine core (Phase 1 of lxdialog implementation). This is foundational — every keybinding depends on it.

---

### Pitfall 2: `read -rsn1` — Not POSIX (Single-Character Read)

**What goes wrong:** Bash-only options `-n`, `-s`, `-t`, `-d` on the `read` builtin are not POSIX. Only `read -r` is standardized. Using `read -n1` to read a single keypress works in bash but fails silently in dash/ash/busybox (it reads an entire line instead of one character).

**Why it happens:** The current codebase uses `dd bs=1 count=1 </dev/tty` (lines 90, 92) which is a correct POSIX workaround — but the lxdialog engine rewrite might "improve" this to `read -rsn1` for bash performance, breaking POSIX compatibility.

**Consequences:** The TUI hangs waiting for Enter after every keypress, making navigation impossible on dash/ash.

**Prevention:**
- Keep the `dd` approach as the POSIX fallback
- Use a shell detection pattern:
```sh
# Fast path for bash/zsh, portable path for everything else
if [ -n "${BASH_VERSION:-}" ] || [ -n "${ZSH_VERSION:-}" ]; then
  _read_key() { IFS= read -rsn1 key; }
else
  _read_key() { key=$(dd bs=1 count=1 2>/dev/null </dev/tty || true); }
fi
```
- **Never** use `read -t` (timeout) in POSIX code — it's bash/ksh only
- ShellCheck flags: **SC3045** (`read -rsn1` is not POSIX)

**Detection:**
```bash
shellcheck -s sh script.sh  # flags SC3045
grep -n 'read.*-[a-z]*[nstd]' script.sh
```

**Phase:** TUI engine core (Phase 1). This is the input layer — get it wrong and nothing works.

---

### Pitfall 3: `local` Is Not POSIX (But Widely Supported)

**What goes wrong:** `local` is not defined by POSIX. It works in dash, bash, zsh, ash, and busybox sh as a de-facto extension, but has **inconsistent behavior** across shells. In particular, `local var=$(cmd; echo $?)` captures the wrong exit code in some shells because `local` itself returns 0.

**Why it happens:** `local` is so widely available that developers assume it's POSIX. The LSB specification mandates it, and dash supports it. But the semantics differ.

**Consequences:** Exit codes silently swallowed. In dash, `local a=5 b=6` makes `b` global (old versions). Complex bugs in functions that check command success after `local`.

**Prevention:**
- Use `local` (it's safe for dash/ash/bash/zsh/busybox) but **never on the same line as a command substitution whose exit code matters**:
```sh
# BAD — exit code of cmd is lost
local result=$(cmd)

# GOOD — separate declaration
local result
result=$(cmd)
```
- ShellCheck flag: **SC3043** (warns about `local` in POSIX sh, but safe to ignore for this project's target shells)
- If strict POSIX compliance were required, use `funcname_varname` naming convention instead

**Detection:**
```bash
shellcheck -s sh script.sh  # SC3043 warnings
grep -n 'local.*=\$(.*)' script.sh
```

**Phase:** All phases — coding standard from day one.

---

### Pitfall 4: `echo -e` / `echo -n` — Unportable Output

**What goes wrong:** POSIX does not define any flags for `echo`. In dash, `echo -e "foo"` literally prints `-e foo`. In some shells, `echo -n` is the default behavior. The behavior is so inconsistent that POSIX explicitly says applications should use `printf` instead.

**Why it happens:** Developers use `echo -e` for ANSI color output or `echo -n` for prompts. Works in bash, breaks in dash.

**Consequences:** ANSI color codes printed as literal text, or `-e` / `-n` shown in the UI. The TUI renders incorrectly.

**Prevention:**
- **Always use `printf`** for any output that needs escape sequences or should not append a newline
- `echo "text"` (plain, no flags) is safe for simple output
- ShellCheck flags: **SC3037** (`echo -e`), **SC3038** (`echo -n`), **SC2039**

**Detection:**
```bash
shellcheck -s sh script.sh  # SC3037, SC3038
grep -n 'echo\s\+-[en]' script.sh
```

**Phase:** All phases — coding standard from day one.

---

### Pitfall 5: ANSI Escape Sequence Length Miscalculation

**What goes wrong:** The existing `str_len()` function (checklist.sh:99-103) tries to strip ANSI sequences using `sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'`. This breaks on **macOS BSD sed** and **BusyBox sed** which don't support `\x1b` as a hex escape in the pattern. The `menu.sh` variant uses `$(printf '\033')` which is more portable but still fragile.

**Why it happens:** The sed pattern seems to work because GNU sed (Linux default) supports `\x1b`. Developers on Linux never see the bug.

**Consequences:** Label truncation is wrong on macOS and Alpine (busybox). Long colored labels overflow the box boundary, corrupting the TUI layout. Text wraps unexpectedly, breaking the carefully positioned cursor coordinates.

**Prevention:**
- Use the `$(printf '\033')` approach (construct the ESC character portably):
```sh
_esc=$(printf '\033')
clean=$(printf '%s' "$label" | sed "s/$_esc\[[0-9;]*[a-zA-Z]//g")
```
- Or use `awk` instead of `sed` for ANSI stripping (more predictable across platforms):
```sh
printf '%s' "$label" | awk '{ gsub(/\033\[[0-9;]*[a-zA-Z]/, ""); print }'
```
- Test on macOS and Alpine explicitly

**Detection:**
```bash
# Run on BSD sed (macOS)
echo $'\033[31mRed Text\033[0m' | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'
# If output still contains color codes → bug confirmed
```

**Phase:** TUI engine core (Phase 1) — the rendering layer depends on correct length calculation.

---

### Pitfall 6: Terminal State Corruption on Interrupt

**What goes wrong:** If the script exits abnormally (Ctrl-C, error, kill signal) without restoring terminal settings, the terminal is left in raw mode: no echo, no line buffering. The user sees a "broken terminal" where typing produces no visible output.

**Why it happens:** The current `term_init()` saves stty settings and sets a trap for INT/TERM/HUP (checklist.sh:66-71), but this is fragile:
- `set -e` can cause early exits that bypass the trap
- Nested function calls with their own traps overwrite the restore trap
- `kill -9` cannot be caught
- PowerShell has completely different signal handling

**Consequences:** User's terminal is unusable after script crash. They must type `reset` or `stty echo` blindly.

**Prevention:**
- Register the cleanup trap **immediately** after changing terminal settings
- Use multiple signal handlers:
```sh
_term_saved_stty=$(stty -g 2>/dev/null || true)
_term_restore() {
  [ -n "$_term_saved_stty" ] && stty "$_term_saved_stty" 2>/dev/null
  printf '\033[?25h'  # show cursor
  printf '\033[0m'    # reset attributes
  printf '\033[?7h'   # re-enable auto-wrap
}
trap '_term_restore; exit 130' INT TERM HUP QUIT ALRM USR1 USR2
```
- Save/restore at the **outermost level** (not inside nested functions)
- Add a `finally`-style cleanup in the main loop
- For PowerShell, use `try/finally` blocks

**Detection:**
- Kill the script with `Ctrl-\` (SIGQUIT) or `kill -9` — terminal left broken?
- Run `set -e` combined with a failing command inside TUI mode

**Phase:** TUI engine core (Phase 1) — must be bulletproof before anything else.

---

### Pitfall 7: Full-Screen Redraw Performance on `dd`-Based Input

**What goes wrong:** The current checklist renders by calling `clear_screen` + full redraw on every keypress (checklist.sh:258). Each keypress spawns **3 processes** (`dd` three times for escape sequences) plus the entire rendering pipeline of `printf` calls. On slow terminals (serial, SSH with latency, tmux over WAN), this causes visible flicker and input lag.

**Why it happens:** The `while :; do render; read_key; ... done` loop is simple to write but redraws the entire screen even when only the cursor position changed.

**Consequences:**
- Noticeable flicker on every keypress over SSH
- 200-500ms input lag on high-latency connections
- CPU spikes from spawning `dd` processes on each keypress

**Prevention:**
- **Incremental rendering**: Only update the lines that changed (old cursor position → new cursor position)
- Use `printf '\033[K'` (clear to end of line) instead of full screen clear
- Pre-compute the static frame and only update dynamic elements
- On bash, use `read -rsn1` instead of `dd` for ~10x faster key reads
- Batch `printf` calls into a single output using a variable:
```sh
buf=""
buf="${buf}\033[${line};3H"     # move cursor
buf="${buf}\033[7m${mark} ${label}\033[0m"
printf '%b' "$buf"  # single write
```

**Detection:**
- Run over `ssh -o Latency=200ms` — feel the lag
- Profile with: `strace -e trace=write -c ./checklist.sh --demo`

**Phase:** TUI rendering optimization (Phase 2, after basic functionality works). Don't optimize prematurely but design the architecture to support incremental updates.

---

## Moderate Pitfalls

### Pitfall 8: Multi-Byte Escape Sequence Parsing Timing

**What goes wrong:** Arrow keys send 3-byte sequences: `ESC [ A` (up), `ESC [ B` (down), etc. Function keys send longer sequences: `ESC [ 1 5 ~` (PgUp). The current `read_key()` reads exactly 2 bytes after ESC, but some terminals send **more** bytes (e.g., `ESC [ 1 ; 5 A` for Ctrl+Arrow). If bytes arrive with network latency, the second `dd` call may return partial data.

**Why it happens:** The `dd bs=1 count=2` approach assumes all remaining bytes are available immediately. Over SSH or in screen/tmux, bytes can arrive in separate TCP packets.

**Consequences:** Arrow keys sometimes don't register, or the leftover bytes "leak" into the next key read, causing phantom keypresses or a stuck UI.

**Prevention:**
- Add a small inter-byte delay: `stty min 1 time 1` (10ms timeout between bytes)
- Or use a micro-sleep between dd reads:
```sh
seq1=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
# If first byte is '[' or 'O', read more with timeout
case "$seq1" in
  '['|'O')
    # brief wait for more bytes
    seq2=$(dd bs=1 count=1 2>/dev/null </dev/tty || true)
    key="$esc$seq1$seq2"
    # Check if we need yet another byte (for [1;5A type sequences)
    ;;
esac
```
- Use `stty min 0 time 2` (200ms timeout) when reading additional sequence bytes so `dd` returns after timeout if no more bytes arrive
- Map only the sequences you actually handle, ignore everything else

**Detection:**
- Run over high-latency SSH: `ssh -o ProxyCommand="nc -q1 host 22"` with artificial delay
- Press arrow keys rapidly — do some get lost?

**Phase:** TUI engine core (Phase 1) — key reading is fundamental.

---

### Pitfall 9: Terminal Resize Handling

**What goes wrong:** The current code reads terminal dimensions once at initialization (checklist.sh:243-244: `tput lines` / `tput cols`) and never updates them. If the user resizes the terminal window, the TUI renders at the old dimensions — causing text to wrap, overflow, or leave stale characters.

**Why it happens:** Handling `SIGWINCH` (window change signal) is complex in shell. The signal interrupts the `dd` read, which returns empty, which can break the main loop.

**Consequences:** UI corruption on resize. The box overflows the terminal. Stale characters from the old layout remain visible.

**Prevention:**
- Trap SIGWINCH and set a flag, then re-read dimensions in the render loop:
```sh
_need_resize=0
trap '_need_resize=1' WINCH
# In main loop:
if [ "$_need_resize" -eq 1 ]; then
  rows=$(tput lines 2>/dev/null || printf 24)
  cols=$(tput cols 2>/dev/null || printf 80)
  _need_resize=0
fi
```
- **Not all shells support `trap ... WINCH`**: dash supports it on Linux but not all platforms. Test on all targets.
- Fallback: re-read dimensions on every render cycle (slight performance cost but simpler)
- PowerShell: use `[Console]::WindowWidth` / `[Console]::WindowHeight` and check each frame

**Detection:**
- Launch TUI, resize terminal window — does the UI adapt?
- `trap -l` in dash — is WINCH listed?

**Phase:** TUI engine core (Phase 1) for basic trap; Phase 2 for robust handling.

---

### Pitfall 10: `tput` Not Available or Returns Wrong Values

**What goes wrong:** `tput lines` and `tput cols` depend on the `TERM` environment variable and a properly installed terminfo/termcap database. In minimal Docker containers, Alpine initramfs, or CI environments, `tput` may not exist or may return empty/wrong values. The current fallback `printf 24` / `printf 80` is correct but may mask the issue.

**Why it happens:** Container images like `alpine` or `scratch` don't include ncurses/terminfo by default. The `TERM` variable may be unset or set to `dumb`.

**Consequences:** TUI renders assuming 80x24 when the terminal is actually much larger or smaller. Box layout is wrong.

**Prevention:**
- Always provide fallbacks:
```sh
rows=$(tput lines 2>/dev/null) || rows=24
cols=$(tput cols 2>/dev/null) || cols=80
[ "$rows" -lt 1 ] 2>/dev/null && rows=24
[ "$cols" -lt 1 ] 2>/dev/null && cols=80
```
- Also try `stty size` as a secondary fallback (works on Linux without terminfo):
```sh
if ! rows=$(tput lines 2>/dev/null) || [ -z "$rows" ]; then
  if dims=$(stty size 2>/dev/null); then
    rows=${dims%% *}
    cols=${dims##* }
  else
    rows=24; cols=80
  fi
fi
```
- Clamp to minimum usable size: `[ $rows -lt 12 ] && rows=12`
- For PowerShell: `[Console]::WindowWidth` and `$Host.UI.RawUI.WindowSize`

**Detection:**
- Run in `docker run --rm -it alpine sh` — does `tput` work?
- Set `TERM=dumb` and run — does it fall back gracefully?

**Phase:** TUI engine core (Phase 1).

---

### Pitfall 11: Remote Script Fetching Security (curl | sh)

**What goes wrong:** The project uses `curl | sh` for remote module fetching (fu.sh lines 511, 1588, 1769, etc.). This is vulnerable to:
1. **MITM attacks** — unencrypted HTTP or compromised WiFi
2. **DNS hijacking** — attacker redirects `raw.githubusercontent.com`
3. **GitHub CDN compromise** — serving malicious scripts from the legitimate domain
4. **Supply chain** — upstream install script changes behavior between runs

**Why it happens:** `curl | sh` is the project's distribution model (stated in PROJECT.md). It's convenient but inherently trusts the network path.

**Consequences:** Arbitrary code execution on the developer's machine. Full user-level access.

**Prevention (in order of effort):**
1. **Always use HTTPS** — `curl -fsSL https://...` (already done) — prevents passive sniffing but NOT active MITM
2. **Pin to commit SHA** — `https://raw.githubusercontent.com/C-Fu/dev-fu/<SHA>/module.sh` instead of branch name
3. **Checksum verification** — embed expected SHA256 in flu.sh, verify after download:
```sh
expected="abc123..."
actual=$(sha256sum "$tmpfile" | cut -d' ' -f1)
[ "$expected" = "$actual" ] || { echo "Integrity check failed"; exit 1; }
```
4. **Content-Type validation** — check that GitHub returns `text/plain`
5. **Display what will be executed** — `less` before `sh`, or at least show the URL and checksum

**Detection:**
- Intercept with `mitmproxy` — can you inject content?
- Check if `raw.githubusercontent.com` responses have integrity headers

**Phase:** Security hardening (Phase 3 or later). The basic module fetching works without verification, but pinning should be added before public release.

---

### Pitfall 12: POSIX `sed` vs GNU `sed` Divergence

**What goes wrong:** Several sed patterns in the codebase use GNU extensions:
- `\x1b` hex escapes (checklist.sh:100, 109) — not in POSIX sed
- `\+` for "one or more" — GNU sed; POSIX sed uses `\{1,\}`
- `\?` for "zero or one" — GNU sed; POSIX sed uses `\{0,1\}`
- `\|` for alternation — GNU sed; POSIX sed doesn't support it
- `-i` for in-place editing — not POSIX; BSD sed requires `-i ''`

**Why it happens:** Every Linux distro ships GNU sed. Developers never test on macOS or BusyBox.

**Consequences:** Text processing silently produces wrong output on macOS/Alpine. Labels not truncated, colors not stripped, substitutions not applied.

**Prevention:**
- Use `awk` instead of `sed` for complex text processing (more portable)
- For simple substitutions, use POSIX shell parameter expansion: `${var#pattern}`, `${var%pattern}`
- When sed is necessary, use only POSIX BRE (basic regular expressions)
- For in-place editing, use the portable pattern:
```sh
tmp=$(mktemp)
sed 's/pattern/replacement/g' "$file" > "$tmp" && mv "$tmp" "$file"
```
- Test with `POSIXLY_CORRECT=1 sed ...` on Linux to catch GNU extensions

**Detection:**
```bash
# macOS test
echo "test" | sed 's/\+/REPLACEMENT/g'
# Alpine test
echo "test" | busybox sed 's/\+/REPLACEMENT/g'
```

**Phase:** All phases — coding standard.

---

## Minor Pitfalls

### Pitfall 13: `eval` for Simulated Arrays

**What goes wrong:** The current code uses `eval "item_tag_$idx=\$tag"` to simulate arrays in POSIX sh (checklist.sh:225-237). While the sanitization (`sed "s/'/'\\\\''/g"`) appears correct, `eval` is a constant security concern and makes the code harder to reason about.

**Prevention:**
- This is the standard POSIX workaround for arrays — acceptable if sanitization is correct
- Consider a newline-delimited string approach as an alternative:
```sh
tags=""
for a in "$@"; do
  tag=$(printf '%s' "$a" | awk -F'|' '{print $1}')
  tags="${tags}${tags:+
}${tag}"
done
# Access by index:
get_index() { echo "$1" | sed -n "${2}p"; }
```
- ShellCheck: SC2086, SC2068 — ensure no unquoted expansions reach `eval`

**Phase:** TUI engine core (Phase 1) — acceptable as-is, but consider the newline-delimited approach.

---

### Pitfall 14: `stty -g` Output Format Varies

**What goes wrong:** `stty -g` output format differs between platforms (Linux vs macOS vs BusyBox). Saving and restoring with `stty "$saved"` works on Linux but may fail on macOS if the format is incompatible.

**Prevention:**
- Always append `2>/dev/null || true` to `stty` commands
- Test restore on all target platforms
- If `stty -g` fails, fall back to `stty sane` as a best-effort restore

**Phase:** TUI engine core (Phase 1).

---

### Pitfall 15: PowerShell ANSI Escape Code Handling

**What goes wrong:** PowerShell 5.1 (Windows PowerShell) does not natively support ANSI escape sequences in the console host — they appear as raw `←[31m` text. PowerShell 7+ (pwsh) supports them via `$([char]27)` or `` `$([char]0x1b) ``, but the syntax is completely different from bash.

**Why it happens:** Windows Console historically used the Win32 API for colors, not ANSI. Windows Terminal added ANSI support, but older PowerShell hosts didn't.

**Consequences:** The TUI displays raw escape codes on Windows PowerShell 5.1. The PowerShell port (`fu.ps1`) must have completely separate rendering code.

**Prevention:**
- In PowerShell, use `` $esc = [char]27 `` or `` $esc = "`e" `` (PowerShell 7+)
- For PowerShell 5.1, use `Write-Host -ForegroundColor` for colors (no cursor positioning)
- Consider using `[System.Console]::SetCursorPosition()` for cursor control in PowerShell
- The TUI engine should be a **separate implementation** for PowerShell, not a port of the ANSI code

**Detection:**
- Run `printf '\033[31mRED\033[0m'` in PowerShell 5.1 on Windows
- Check `$PSVersionTable.PSVersion.Major` — 5 vs 7+

**Phase:** PowerShell TUI implementation (parallel phase). Must be a separate implementation, not a translation.

---

### Pitfall 16: Alternate Screen Buffer Not Restored

**What goes wrong:** Using `printf '\033[?1049h'` to switch to the alternate screen buffer (common for full-screen TUI) without restoring with `printf '\033[?1049l'` on exit leaves the terminal in the alternate buffer. The user's shell history and previous output are invisible.

**Prevention:**
- Always pair enter/exit alternate screen in the cleanup trap
- Not all terminals support alternate screen — test the sequence and fall back to regular screen clearing
- For the lxdialog engine, consider whether alternate screen is actually needed (the current checklist.sh doesn't use it)

**Phase:** TUI engine core (Phase 1) if alternate screen is used.

---

### Pitfall 17: tmux/screen Escape Sequence Interference

**What goes wrong:** tmux and screen intercept and sometimes modify escape sequences. Specifically:
- tmux may translate `ESC [ A` to `ESC O A` depending on terminal mode
- screen can buffer escape sequences causing timing issues
- Both multiplexers add their own escape sequence processing layer

**Prevention:**
- Handle both `ESC [ A` and `ESC O A` variants for arrow keys (current code already does this — checklist.sh:317-318)
- Test in `TERM=screen` and `TERM=tmux` environments
- Consider checking `$TMUX` and `$TERM` environment variables to detect multiplexer mode

**Detection:**
- Run inside `tmux` and `screen` — do all keys work?
- Check `echo $TERM` inside and outside tmux/screen

**Phase:** TUI engine core (Phase 1) for key handling; testing throughout.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| POSIX TUI engine core | `$'\033'` not POSIX (#1) | Use `$(printf '\033')` |
| POSIX TUI engine core | `read -n` not POSIX (#2) | Use `dd` fallback with shell detection |
| POSIX TUI engine core | Terminal state corruption (#6) | Multi-signal trap, outermost-level restore |
| POSIX TUI engine core | `sed \x1b` not portable (#5, #12) | Use `$(printf '\033')` in sed or switch to awk |
| Key handling | Multi-byte sequence timing (#8) | Inter-byte timeout with `stty min 0 time 2` |
| Key handling | tmux/screen interference (#17) | Handle both `[` and `O` escape forms |
| Rendering | Full-screen redraw flicker (#7) | Incremental rendering, buffered output |
| Layout | Terminal resize (#9) | SIGWINCH trap + dimension re-read |
| Layout | `tput` unavailable (#10) | `stty size` fallback, minimum size clamping |
| Remote modules | curl pipe sh security (#11) | HTTPS + SHA pinning + commit SHA URLs |
| PowerShell TUI | ANSI not supported in PS 5.1 (#15) | Separate PowerShell TUI implementation |
| PowerShell TUI | Different signal handling (#6) | `try/finally` blocks |
| All phases | `echo -e`/`echo -n` unportable (#4) | Always use `printf` |
| All phases | `local` exit code swallowing (#3) | Separate declaration from assignment |
| Testing | No CI testing on dash/ash/busybox | Add shellcheck + multi-shell test matrix |

## ShellCheck Warnings That Matter for TUI Code

The following ShellCheck warning codes are critical for this project's TUI code:

| Code | What | Severity | Action |
|------|------|----------|--------|
| SC2039 | Feature undefined in POSIX sh | Critical | Fix immediately |
| SC3037 | `echo` flags not POSIX | Critical | Replace with `printf` |
| SC3043 | `local` not POSIX | Low | Accept (supported by all target shells) |
| SC3045 | `read` options not POSIX | Critical | Use `dd` fallback |
| SC3018 | `++` not POSIX | Medium | Use `i=$((i+1))` |
| SC3019 | `**` not POSIX | Low | Not used in TUI code |
| SC3003 | `$'...'` not POSIX | Critical | Use `$(printf '\033')` |
| SC2086 | Double quote to prevent globbing | Medium | Always quote in TUI code |
| SC2068 | Double quote array expansion | Medium | Check all `eval` sites |

## Existing Codebase Issues (From Analysis)

The following pitfalls are **already present** in the codebase and will be inherited unless addressed:

1. **checklist.sh:91-93** — `$'\033'` used extensively (Pitfall #1)
2. **checklist.sh:99-103** — `sed 's/\x1b...'` not portable (Pitfall #5)
3. **checklist.sh:90,92** — `dd bs=1` spawns 3 processes per keypress (Pitfall #7)
4. **checklist.sh:243-244** — Terminal dimensions read once, never updated (Pitfall #9)
5. **checklist.sh:302-368** — All key matching uses `$'\033'` syntax (Pitfall #1)
6. **menuWSL.sh:58-64** — `str_len()` broken (malformed pipe, `esc` variable not passed to sed)
7. **fu.sh:146** — `eval "$cmd"` in `retry_network()` (Pitfall #11 adjacent)
8. **fu.ps1:82-85** — `Get-DetectOs` always returns "windows" (PowerShell bug)

---

## Sources

- ShellCheck Wiki: https://www.shellcheck.net/wiki/SC2039 (POSIX sh undefined features)
- ShellCheck Wiki: https://www.shellcheck.net/wiki/SC3045 (read options not POSIX)
- ShellCheck Wiki: https://www.shellcheck.net/wiki/SC3037 (echo flags not POSIX)
- ShellCheck Wiki: https://www.shellcheck.net/wiki/SC3043 (local not POSIX)
- Wooledge Bashism page: https://mywiki.wooledge.org/Bashism
- Ubuntu DashAsBinSh: https://wiki.ubuntu.com/DashAsBinSh
- NCURSES terminfo database: https://invisible-island.net/ncurses/terminfo.src.html
- NCURSES FAQ: https://invisible-island.net/ncurses/ncurses.faq.html
- Bash reference manual (read builtin): https://www.gnu.org/software/bash/manual/
- Existing codebase analysis: `.planning/codebase/CONCERNS.md`
- Confidence: HIGH for all pitfalls (verified against official documentation, multiple independent sources agree)
