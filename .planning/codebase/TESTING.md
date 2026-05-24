# Testing Patterns

**Analysis Date:** 2026-05-23

## Test Framework

**Runner:**
- Not applicable — no automated test framework is configured
- No test runner, test harness, or CI pipeline detected
- No test configuration files present (no `Makefile`, no `bats` setup, no CI config)

**Assertion Library:**
- Not applicable

**Run Commands:**
```bash
# No test command exists
# Manual testing only:
bash fu.sh              # Interactive menu mode
bash fu.sh 5            # CLI mode — install Docker
bash fu.sh --help       # Not implemented
./checklist.sh --demo   # Demo mode for checklist widget
```

## Test File Organization

**Location:**
- No test files exist in the repository
- No test directories (`tests/`, `test/`, `spec/`, `__tests__/`)

**Naming:**
- No naming convention for tests (none exist)

**Structure:**
```
dev-fu/
├── fu.sh              # Main script (no tests)
├── fu.ps1             # PowerShell variant (no tests)
├── checklist.sh       # Standalone checklist widget (has --demo mode)
├── menu.sh            # Checklist variant (has --demo mode)
├── menuWSL.sh         # WSL-specific checklist variant (has --demo mode)
├── fancy_blue.sh      # Prompt script (no tests)
├── web.sh             # Simple HTTP server (no tests)
├── README.md
└── npm_error.log      # Debug log (not a test artifact)
```

## Test Structure

**Suite Organization:**
- Not applicable — no test suites exist

**Demo Mode (closest to testing):**
`checklist.sh`, `menu.sh`, and `menuWSL.sh` include a `--demo` flag that exercises the checklist UI:
```bash
if [ "${1:-}" = "--demo" ]; then
  checklist "Select Features" "Choose features to enable:" \
    "core|Core utilities|on" \
    "net|Networking tools|off" \
    "dev|Development tools|off" \
    "docs|Documentation and help files|off" \
    "extras|Extra utilities with a long label that will be truncated|off"
  rc=$?
  if [ $rc -eq 0 ]; then
    echo "Selected:"
    cat
  else
    echo "Cancelled" >&2
  fi
  exit $rc
fi
```

## Manual Testing Approach

**Interactive Testing:**
- Run `bash fu.sh` to test the full interactive menu
- Run `bash fu.sh <option_numbers>` to test CLI mode (e.g., `bash fu.sh 5 11 -9`)
- Run `./checklist.sh --demo` to test the checklist widget independently

**Platform Testing:**
- The project explicitly targets multiple platforms (Alpine, Debian, macOS, WSL2, ChromeOS, Termux, Windows)
- Testing is done manually across environments
- Platform detection functions can be tested in isolation:
  ```bash
  # Source and call detection functions
  source fu.sh  # (would run the menu — not practical)
  # Instead, extract and test individual functions
  ```

**Status Check as a Smoke Test:**
- Option 1 (Status Check) in `fu.sh` serves as a verification tool:
  ```bash
  status_check()  # Lists installed tools and versions
  ```
- Option 2 (Compare With Latest) validates network connectivity and API access

## Testing Gaps

**What is NOT tested:**
- Install/remove function success/failure paths
- Platform detection accuracy across OS variants
- Package manager abstraction (`pkg_install`, `pkg_remove`) across distros
- Error handling paths (network failures, missing dependencies)
- Prompt generation (`_write_prompt_purple`, `_write_prompt_blue`)
- Input parsing edge cases (`parse_input` with invalid/ambiguous input)
- Upgrade logic for each tool
- Idempotency (running install twice, removing then installing)

## Recommendations for Adding Tests

**Framework Options (for shell scripts):**
- [Bats](https://github.com/bats-core/bats-core) — Bash Automated Testing System
- [shelltestrunner](https://github.com/gavinbeatty/shelltestrunner) — simpler alternative
- [shunit2](https://github.com/kward/shunit2) — xUnit-style for POSIX shells

**Suggested Test Structure:**
```
tests/
├── helpers/
│   ├── mock_pkg_manager.sh    # Mock pkg_install, pkg_remove
│   └── mock_commands.sh       # Mock command -v, curl, etc.
├── unit/
│   ├── detect_platform.bats   # Test OS/distro detection
│   ├── parse_input.bats       # Test input parsing logic
│   ├── pkg_manager.bats       # Test package manager abstraction
│   └── helpers.bats           # Test retry_network, append_rc_if_missing
├── integration/
│   ├── status_check.bats      # Test status check output
│   └── install_remove.bats    # Test install/remove pairs (with mocks)
└── fixtures/
    └── fake_os_release        # Mock /etc/os-release contents
```

**Key Functions to Test First:**
- `detect_platform()` — critical for correct behavior, platform-dependent
- `parse_input()` — complex input validation with many edge cases
- `pkg_install()` / `pkg_remove()` / `pkg_update()` — dispatch logic
- `retry_network()` — retry behavior, failure accumulation
- `append_rc_if_missing()` — idempotent rc file modification
- `detect_rc_file()` — shell detection

**Mocking Strategy:**
- Override `command -v` with a function that returns predefined results
- Set `DETECTED_OS`, `DETECTED_DISTRO` directly instead of relying on system detection
- Mock network calls by replacing `curl` with a wrapper in `$PATH`
- Use `FAKE_ROOT` temp directory for file operation tests

## Coverage

**Requirements:** None enforced

**Current Coverage:**
- 0% automated test coverage — no test files exist
- Manual coverage is implied by the wide platform support matrix in the README

## Existing Validation Mechanisms

**Self-Checks in the Script:**
- `command -v <tool>` checks before attempting install (idempotency guard)
- Platform detection at startup sets global variables used for branching
- `_is_musl()` check diverts Alpine users to alternative install paths
- `ensure_sudo()` validates sudo availability before system operations
- `status_check()` and `status_check_compare()` serve as runtime verification

**Defensive Patterns:**
- `|| true` on cleanup operations to prevent cascade failures
- `2>/dev/null` on version checks to handle missing commands gracefully
- `timeout` wrapping on version commands that might hang (e.g., `echo "y" | timeout 5 $cmd $flag`)

---

*Testing analysis: 2026-05-23*
