# Codebase Concerns

**Analysis Date:** 2026-05-23

## Tech Debt

**Massive monolithic file:**
- Issue: `fu.sh` is 2,629 lines in a single file — installs for 14+ distinct tools, platform detection, menu system, version comparison, and prompt generation all crammed together
- Files: `fu.sh`
- Impact: Extremely difficult to maintain, test, or debug individual install functions. Adding a new tool requires scrolling through thousands of lines. Merge conflicts are likely with multiple contributors.
- Fix approach: Extract each install/remove pair into `src/installers/<tool>.sh` and source them. Keep platform detection and menu in `fu.sh` as the orchestrator.

**PowerShell port is a near-full copy:**
- Issue: `fu.ps1` (1,971 lines) duplicates all logic from `fu.sh` independently. Changes to one must be manually mirrored to the other, with no guarantee of parity.
- Files: `fu.ps1`, `fu.sh`
- Impact: Feature drift between bash and PowerShell versions. Bug fixes applied to one may be missed in the other.
- Fix approach: Consider a shared data-driven approach where tool definitions (names, URLs, package names per platform) are in a common format, and the bash/PS scripts are thin platform-specific shells.

**Three nearly-identical checklist implementations:**
- Issue: `menu.sh` (654 lines), `menuWSL.sh` (574 lines), and `checklist.sh` (596 lines) are 95%+ identical code with minor whitespace/sed escaping differences. All three embed the same fish implementation.
- Files: `menu.sh`, `menuWSL.sh`, `checklist.sh`
- Impact: Any bug fix or feature addition must be applied three times. The `error at line 64 expected bracket.txt` file is a fourth copy of the same code (with the broken `str_len` / `truncate_label` functions).
- Fix approach: Keep only `checklist.sh` as the canonical source. Delete `menu.sh` and `menuWSL.sh` or make them symlinks/wrappers that source `checklist.sh`.

**`fancy_blue.sh` is a standalone duplicate of embedded prompt code:**
- Issue: The blue prompt theme is defined in three places: (1) standalone `fancy_blue.sh`, (2) embedded heredoc inside `_write_prompt_blue()` in `fu.sh`, (3) embedded heredoc inside `Write-PromptBlue()` in `fu.ps1`. They are identical copies.
- Files: `fancy_blue.sh`, `fu.sh` (lines 985-1135), `fu.ps1` (lines 498-648)
- Impact: Prompt bug fixes need to be replicated in three places.
- Fix approach: Keep `fancy_blue.sh` as the canonical source. Have `_write_prompt_blue()` copy from it instead of embedding.

**`npm_error.log` committed to repo:**
- Issue: A 629-line npm debug log from a failed `npm i -g @openchamber/web` install is committed to the repository.
- Files: `npm_error.log`
- Impact: Clutters the repo, leaks internal path information (`/root/.nvm/versions/node/v24.15.0/`), provides no value to users.
- Fix approach: Delete the file and add `*.log` to `.gitignore`.

**Stale error report committed as a file:**
- Issue: `error at line 64 expected bracket.txt` is a copy of `menuWSL.sh` saved as a debugging artifact. It contains the same broken `str_len`/`truncate_label` functions that don't work in POSIX `sh`.
- Files: `error at line 64 expected bracket.txt`
- Impact: No functional impact but adds confusion. The filename itself is a breadcrumb of an unresolved bug.
- Fix approach: Delete the file. The underlying bug should be fixed in `menuWSL.sh` and `checklist.sh` (see Fragile Areas below).

## Known Bugs

**`str_len()` and `truncate_label()` broken in `menuWSL.sh` and `error at line 64 expected bracket.txt`:**
- Symptoms: `str_len()` at `menuWSL.sh:58-64` has a malformed pipe — the `esc=$(printf '\033')` variable assignment inside a pipeline means `sed` never receives the `esc` variable. The pipe character is placed incorrectly, splitting the command into two separate invocations.
- Files: `menuWSL.sh` (lines 58-64, 67-80), `error at line 64 expected bracket.txt` (lines 58-64, 67-80)
- Trigger: Any call to `str_len()` or `truncate_label()` in `menuWSL.sh` will fail to strip ANSI codes, causing label truncation to be incorrect for colored labels.
- Workaround: Use `menu.sh` or `checklist.sh` instead, which use different sed escaping approaches (though `checklist.sh` uses `\x1b` which may not work with all sed implementations either).

**PowerShell `Get-DetectOs` always returns "windows":**
- Symptoms: The function at `fu.ps1:82-85` always returns `"windows"` regardless of actual OS. The `$IsWindows` variable is only available in PowerShell 7+ (not Windows PowerShell 5.1), and even then, it's always true when running `fu.ps1` on Windows — making the function pointless but not harmful.
- Files: `fu.ps1` (lines 82-85)
- Trigger: Runs on any Windows system.
- Workaround: Harmless since `fu.ps1` is only used on Windows.

**PowerShell fancy prompt writes bash syntax to `.ps1` files:**
- Symptoms: `Write-PromptPurple()` in `fu.ps1` (lines 256-494) writes bash-specific syntax (e.g., `declare -A`, `local`, `$(__fg ...)`, `PROMPT_COMMAND="prompt"`) into a `.ps1` file (`$env:USERPROFILE\.fancy-prompt.ps1`). This code cannot execute in PowerShell.
- Files: `fu.ps1` (lines 256-494, 497-648)
- Trigger: Selecting option 6 (Purple-Pink prompt) or option 7 (Blue prompt) on Windows writes non-functional code to the PowerShell profile, potentially breaking the profile.
- Workaround: None. The fancy prompt options should be disabled or rewritten with native PowerShell prompt logic.

**PowerShell `__needs_pull()` always returns "0":**
- Symptoms: In the purple prompt heredoc embedded in `fu.ps1` (line 413), the comparison `[ $(git rev-parse HEAD) = $(git rev-parse @{u}) ]; then echo "0"; else echo "0"` always outputs "0" regardless of whether the branch needs pulling. The `else` branch should echo "1".
- Files: `fu.ps1` (line 413)
- Trigger: The prompt always shows the default branch color, never the "needs pull" red color.
- Workaround: None. This is a copy-paste error from the original.

**PowerShell `__venv()` condition checks string literal instead of variable:**
- Symptoms: At `fu.ps1` (line 484), the condition reads `if [ "" != __venv ]` comparing against the literal string `__venv` instead of calling `$(__venv)`. This means the venv block is always shown in the prompt, even when no virtual environment is active.
- Files: `fu.ps1` (line 484)
- Trigger: Purple prompt always shows an empty venv block.
- Workaround: None.

**`format_font TEXT_FORMAT_3` in `fancy_blue.sh` has swapped arguments:**
- Symptoms: At `fancy_blue.sh` (line 253), the call is `format_font TEXT_FORMAT_3 $FC3 $FE3 $BG3` but the function signature expects `(output, effect, font_color, bg_color)`. The `$FC3` (font color) and `$FE3` (effect) arguments are swapped compared to lines 251-252 which use `$FE1 $FC1 $BG1` and `$FE2 $FC2 $BG2`.
- Files: `fancy_blue.sh` (line 253)
- Trigger: The PWD segment of the blue prompt may display with wrong formatting (wrong effect applied to the font color parameter).
- Workaround: None.

**`fancy_blue.sh` references undeclared variables `FONT_COLOR_4`, `BACKGROUND_4`, `TEXTEFFECT_4`:**
- Symptoms: Lines 241-254 compute `FC4`, `BG4`, `FE4` and call `format_font TEXT_FORMAT_4`, but `FONT_COLOR_4`, `BACKGROUND_4`, and `TEXTEFFECT_4` are never declared in the configuration section. They will be empty strings, resulting in `format_font` receiving empty/zero arguments.
- Files: `fancy_blue.sh` (lines 241-254)
- Trigger: The 4th prompt segment is generated but never used in PS1, so this is dead code. Still, it produces shell errors if someone adds a 4th segment.
- Workaround: Remove the dead code for segment 4, or add the missing configuration variables.

## Security Considerations

**GitHub token stored in plaintext file:**
- Risk: The GitHub PAT is stored at `$HOME/.config/dev-fu/github-token` (set in `fu.sh:431` and `fu.ps1:121`). While `chmod 600` is applied (`fu.sh:471`), the file contains the raw token with no encryption. Any process running as the same user can read it.
- Files: `fu.sh` (lines 431, 470-471), `fu.ps1` (line 121)
- Current mitigation: `chmod 600` restricts to owner-only. The token is masked on display (first 4 / last 4 chars).
- Recommendations: Document that the token has limited scope (only `public_repo` needed). Consider using system keychain (e.g., `security` on macOS, `secret-tool` on Linux) instead of a plaintext file.

**`eval` used with user-controllable data in `retry_network()`:**
- Risk: `retry_network()` at `fu.sh:139-155` takes a command string and executes it via `eval "$cmd"`. While the current callers pass hardcoded curl commands, the function's API accepts arbitrary strings. If a future caller passes unsanitized input, it becomes a code injection vector.
- Files: `fu.sh` (line 146)
- Current mitigation: All current call sites use static strings. Not exploitable as-is.
- Recommendations: Refactor to accept command as separate arguments and use `"$@"` instead of `eval`.

**`eval` used with GitHub token in `_scc_gh()`:**
- Risk: At `fu.sh:1336`, the token is interpolated into `$auth_header` which is then passed through `eval curl ... $auth_header`. If the token file contained shell metacharacters, they would be interpreted.
- Files: `fu.sh` (lines 1331-1343)
- Current mitigation: GitHub tokens are alphanumeric with no shell metacharacters. Low risk.
- Recommendations: Pass the header directly to curl without `eval`. Use `curl -H "Authorization: token $tok"` directly.

**Piping unverified remote scripts to `sh`:**
- Risk: Multiple install paths download and execute scripts from the internet without verification: `get.docker.com`, `sh.rustup.rs`, `bun.sh/install`, `astral.sh/uv/install.sh`, `nvm-sh/nvm/master/install.sh`, `tailscale.com/install.sh`, `opencode.ai/install`.
- Files: `fu.sh` (lines 511, 1588, 1769, 391-401, 1718, 2038, 2220)
- Current mitigation: `curl -fsSL` (fails on HTTP errors). `retry_network` retries on failure. No checksum or signature verification.
- Recommendations: At minimum, document the security model. Consider adding optional checksum verification for critical install scripts.

**`eval` used extensively in checklist widget:**
- Risk: `menu.sh`, `menuWSL.sh`, and `checklist.sh` use `eval` to create and read dynamic variable names (`item_tag_1`, `item_label_2`, etc.) as a POSIX-compatible substitute for arrays. The labels come from caller-provided arguments.
- Files: `menu.sh` (lines 217-236), `menuWSL.sh` (lines 179-190), `checklist.sh` (lines 225-236)
- Current mitigation: Labels are sanitized via `sed "s/'/'\\\\''/g"` before being placed in single-quoted `eval`.
- Recommendations: The sanitization appears correct. Low risk but worth noting for code reviewers.

## Performance Bottlenecks

**`status_check_compare()` makes 20+ sequential HTTP requests:**
- Problem: The version comparison feature fetches latest versions for each tool sequentially, one HTTP request at a time. With GitHub API rate limiting (60/hr unauthenticated), this can fail on repeated use.
- Files: `fu.sh` (lines 1320-1529)
- Cause: No parallel fetching. Each `_scc_gh` call blocks on a 5-10 second HTTP timeout before proceeding to the next.
- Improvement path: Fetch all GitHub releases in parallel using background processes (`&` / `wait`). Batch npm registry calls. Cache results for 1 hour.

**Purple prompt spawns 6+ git subprocesses per prompt redraw:**
- Problem: The fancy purple prompt calls `__branch_name`, `__branch_is_local_only`, `__branch_is_merged`, `__staged`, `__untracked`, `__changed`, `__stashed`, `__unpushed`, and `__needs_pull` — each spawning a separate `git` subprocess. On slow filesystems (network mounts, large repos), this causes visible prompt lag.
- Files: `fu.sh` (lines 775-883 — the embedded prompt code)
- Cause: Each git command is a separate process invocation. No consolidation.
- Improvement path: Combine multiple `git` queries into a single `git status --porcelain=v2 --branch` call and parse the output once.

**`dd bs=1 count=1` for key reading in checklist widget:**
- Problem: Each keypress in `menu.sh`/`menuWSL.sh`/`checklist.sh` spawns a `dd` process to read a single byte from `/dev/tty`. Escape sequences require two additional `dd` calls. This is inherently slow due to process creation overhead.
- Files: `menu.sh` (lines 82-88), `menuWSL.sh` (lines 47-54), `checklist.sh` (lines 89-96)
- Cause: POSIX sh lacks a built-in single-byte read. `dd` is the only portable option.
- Improvement path: On bash, use `read -rsn1` instead. Fall back to `dd` only for strict POSIX sh.

## Fragile Areas

**`checklist.sh` `str_len()` and `truncate_label()` use sed with `\x1b`:**
- Files: `checklist.sh` (lines 100-103, 109-112)
- Why fragile: The `sed 's/\x1b\[[0-9;]*[a-zA-Z]//g'` pattern depends on the sed implementation supporting `\x1b` as a hex escape. GNU sed supports it, but BusyBox sed and macOS BSD sed may not. The `menu.sh` variant uses `$(printf '\033')` substitution which is more portable.
- Safe modification: Unify on the `$(printf '\033')` approach from `menu.sh` across all checklist variants.

**`_scc_gh()` complex fallback chain:**
- Files: `fu.sh` (lines 1327-1409)
- Why fragile: Each GitHub repo has a different fallback strategy for fetching the latest version (some use releases, some tags, some raw files from master/main, some npm/pypi registries). If any upstream URL changes or repo structure changes, the version check silently fails.
- Test coverage: None. All fallback paths are untested.
- Safe modification: Add a simple caching layer and validate that fetched tags look like semver.

**`append_rc_if_missing()` modifies user shell config:**
- Files: `fu.sh` (lines 124-129)
- Why fragile: Directly appends to `.bashrc` or `.zshrc` using `grep -F` to check for existing lines. If the user's rc file has unusual formatting (e.g., the source line split across lines), it may add duplicates. The `sed -i.bak` in prompt removal creates backup files that are never cleaned up.
- Safe modification: Use a marker comment (e.g., `# >>> dev-fu >>>` / `# <<< dev-fu <<<`) to bracket managed lines.

**DNS swap in `install_avahi()`:**
- Files: `fu.sh` (lines 555-632)
- Why fragile: Overwrites `/etc/resolv.conf` with a symlink to systemd-resolved. If the system already has a custom DNS configuration (e.g., pi-hole, corporate DNS), this silently replaces it. The `remove_avahi()` function hardcodes Google DNS (8.8.8.8, 8.8.4.4) as the fallback, which may not be appropriate in all environments.
- Safe modification: Back up the original `/etc/resolv.conf` before modification. Ask for confirmation specifically about the DNS change. Restore the backup on removal instead of hardcoding Google DNS.

**`web.sh` serves script on `0.0.0.0`:**
- Files: `web.sh` (line 77)
- Why fragile: Binds to all network interfaces by default, exposing the script contents to anyone on the network. No authentication. The PORT variable at line 2 is set to `18765` but immediately overridden by the `PORT = int(os.environ.get("PORT", "8080"))` inside the heredoc, making the shell variable dead code.
- Safe modification: Default to `127.0.0.1` instead of `0.0.0.0`. Remove the dead `PORT=18765` shell variable. Add a note about network security.

## Scaling Limits

**Single-file architecture:**
- Current capacity: One file with 2,629 lines, 18 menu options
- Limit: Adding new tools becomes increasingly error-prone as the file grows. Function name collisions become likely.
- Scaling path: Modularize into sourced files: `src/platform.sh`, `src/package.sh`, `src/installers/*.sh`, `src/prompts/*.sh`.

**No test suite:**
- Current capacity: Zero automated tests across the entire project
- Limit: Any change to platform detection, package management, or install logic can break silently on untested platforms (Alpine, Termux, ChromeOS, zypper-based distros).
- Scaling path: Add shellcheck linting at minimum. Create bats or shunit2 test suites for `detect_platform()`, `get_pkg_manager()`, `pkg_install()`, `parse_input()`, and the checklist widget.

**Hardcoded menu indices:**
- Current capacity: 18 options mapped to parallel arrays (`MENU_LABELS`, `MENU_INSTALL_FN`, `MENU_REMOVE_FN`, `MENU_SINGLE_SELECT`)
- Limit: Adding/removing/reordering options requires updating all four arrays in sync. No compile-time validation that array lengths match.
- Scaling path: Use an associative array or function-per-option pattern where each option self-registers.

## Dependencies at Risk

**External install scripts (no pinning):**
- Risk: All install scripts are fetched from latest URLs. If upstream repos change their URL structure, install script API, or remove the scripts entirely, `fu.sh` will break.
- Impact: Docker (`get.docker.com`), Rust (`sh.rustup.rs`), NVM, Bun, Tailscale, uv, and OpenCode installs all depend on external scripts.
- Migration plan: Pin to specific commit hashes or tagged versions where possible. Cache known-good install scripts locally.

**`npx gsd-opencode@latest` as an installer:**
- Risk: Running `npx <pkg>@latest` downloads and executes the latest version of a package without verification. A compromised npm package or typosquatting attack would have full user-level access.
- Files: `fu.sh` (lines 2097, 2231), `fu.ps1` (line 1529)
- Impact: Full user-level code execution on the developer machine.
- Migration plan: Pin to a specific version. Verify npm package integrity.

## Missing Critical Features

**No `.gitignore` file:**
- Problem: The repository lacks a `.gitignore`. Files like `npm_error.log`, `*.bak` (from `sed -i.bak`), and the error text file have been committed.
- Files: Root directory
- Blocks: Clean repository maintenance.

**No linting or static analysis:**
- Problem: No shellcheck, shfmt, or PSScriptAnalyzer configuration. The `eval` usage, unquoted variables, and other issues would be caught by basic linting.
- Blocks: Code quality enforcement.

**No CI/CD pipeline:**
- Problem: No GitHub Actions, no automated testing, no shellcheck-on-push. Changes are pushed directly to main.
- Blocks: Quality gates before merge.

**No `--version` flag:**
- Problem: Neither `fu.sh` nor `fu.ps1` supports a `--version` flag. There is no version number defined anywhere in the codebase.
- Blocks: Version tracking, rollback, and update notifications.

## Test Coverage Gaps

**Platform detection:**
- What's not tested: `detect_platform()`, `detect_distro()`, `detect_wsl()`, `detect_environment()` — all untested across the 10+ target platforms.
- Files: `fu.sh` (lines 160-205)
- Risk: Platform detection could return wrong values on edge cases (e.g., MSYS2, Cygwin, ChromeOS Crostini variants).
- Priority: High

**Package manager abstraction:**
- What's not tested: `pkg_install()`, `pkg_remove()`, `pkg_purge()`, `pkg_autoremove()` — the 6-package-manager switch blocks.
- Files: `fu.sh` (lines 245-321)
- Risk: Wrong package names or flags for any of the 6 supported package managers.
- Priority: High

**Input parsing:**
- What's not tested: `parse_input()` — handles range validation, deduplication, conflict detection (install + remove same tool), single-select enforcement.
- Files: `fu.sh` (lines 2415-2518)
- Risk: Edge cases like `1,1,1`, `-5 5`, `19`, `0`, `-0`, empty input, or whitespace-only input.
- Priority: Medium

**Checklist widget:**
- What's not tested: The entire TUI checklist across `menu.sh`, `menuWSL.sh`, `checklist.sh` — terminal initialization, key handling, pagination, escape sequence parsing, fallback mode.
- Files: `menu.sh`, `menuWSL.sh`, `checklist.sh`
- Risk: Terminal corruption on unexpected input, broken rendering on unusual terminal sizes.
- Priority: Medium

**Install/Remove functions:**
- What's not tested: Every `install_*()` and `remove_*()` function. Each has platform-specific branching and error handling that cannot be verified without mocking.
- Files: `fu.sh` (lines 485-2362)
- Risk: Install failures on untested distro/architecture combinations go undetected.
- Priority: Low (would require significant mocking infrastructure)

---

*Concerns audit: 2026-05-23*
