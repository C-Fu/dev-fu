# Phase 4: Module Architecture — Research

**Phase:** 4
**Researched:** 2026-05-25
**Status:** Complete

## Research Summary

Phase 4 implements the module execution pipeline: fetch remote scripts from GitHub, parse metadata from comment headers, collect user parameters via TUI widgets, execute in isolated subshells with platform context, and display results in a box modal. The research validates that all technical components are achievable with pure POSIX sh, leveraging the existing Phase 1-3 primitives (tui.sh, menu.sh) and established codebase patterns.

## Domain Analysis

### 1. Remote Script Fetching

**Pattern:** Pipe-to-sh (curl-pipe-bash) — same as the project's distribution model.

```sh
# Existing pattern from fu.sh (already validated)
retry_network 3 5 "curl -fsSL https://raw.githubusercontent.com/.../script.sh -o /tmp/file.sh"
```

**Phase 4 adaptation (D-05):**
```sh
curl -fsSL "$module_url" | sh -s -- "$@"
```

**Key decisions:**
- No temp file (D-05): `curl -fsSL "$url" | sh -s -- "$@"` — pipe directly
- wget fallback: `wget -qO- "$url" 2>/dev/null | sh -s -- "$@"` when curl unavailable
- Retry pattern (D-07): Reuse fu.sh `retry_network()` logic — 3 attempts, 2s delay
- No caching (D-06): Fetch fresh every invocation
- Error reporting (D-08): Display URL + HTTP code + actionable message

**Technical considerations:**
- `curl -f` ensures non-2xx HTTP codes become errors (exit 22)
- `curl -sS` shows errors but silences progress meter
- Pipe exit code capture: `set -o pipefail` to propagate script failures
- Must handle binary executables indirectly — module scripts are shell, they may download binaries
- DNS resolution timeout: `curl --connect-timeout 10`

**URL resolution (D-04):**
- Base: `https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/`
- Action ID `install_python` → `${BASE}install_python.sh`
- Resolver function: `flu_module_resolve_url()` — maps action_id to URL
- Override: `FLU_MODULES_BASE_URL` env var for custom repos

### 2. Metadata Parsing

**Pattern:** awk-based structured comment parsing (D-01, D-03). Same awk-centric approach as the menu.db DSL parser (MENU-04).

**Header format (D-01, D-02):**
```sh
#!/usr/bin/env sh
# @name: Install Python
# @params: scope=radio:global,user;version=text
# @platforms: linux,darwin
# @version: 1.2.3
# @deps: install_python_deps
# @timeout: 300

# (blank line or first non-comment line terminates metadata)
set -euo pipefail
# ... module body ...
```

**Parser implementation (D-01, D-03):**
```sh
flu_module_parse_metadata() {
  # Read script content from stdin, parse @key: value lines
  # Stop at first blank line or line not starting with #
  # Populates: _fmp_name, _fmp_params, _fmp_platforms, _fmp_version,
  #            _fmp_deps, _fmp_timeout
  awk '
    /^$/ { exit 0 }
    !/^#/ { exit 0 }
    /^# @name:/ { gsub(/^# @name: */, ""); name=$0 }
    /^# @params:/ { gsub(/^# @params: */, ""); params=$0 }
    /^# @platforms:/ { gsub(/^# @platforms: */, ""); platforms=$0 }
    /^# @version:/ { gsub(/^# @version: */, ""); version=$0 }
    /^# @deps:/ { gsub(/^# @deps: */, ""); deps=$0 }
    /^# @timeout:/ { gsub(/^# @timeout: */, ""); timeout=$0 }
    END {
      printf "%s\n%s\n%s\n%s\n%s\n%s\n", name, params, platforms, version, deps, timeout
    }
  '
}
```

**Parameter parsing (D-03):**
Input: `scope=radio:global,user;version=text`
- Split on `;` for individual param declarations
- Split each on `=` for name and type:choices
- Split type:choices on `:` for type and comma-separated options

```sh
_flu_parse_params() {
  # Parse "name=type:opt1,opt2;name2=type:opt1,opt2" into indexed arrays
  # Outputs newline-separated: "index|name|type|choices"
  printf '%s' "$1" | awk -F';' '{
    for (i=1; i<=NF; i++) {
      split($i, a, "=")
      name = a[1]
      split(a[2], b, ":")
      type = b[1]
      choices = (length(b) > 1 ? b[2] : "")
      printf "%d|%s|%s|%s\n", i-1, name, type, choices
    }
  }'
}
```

### 3. Parameter Collection

**Pattern:** Use existing Phase 2 widgets for each parameter type (D-10):

| Param Type | Widget | Function |
|------------|--------|----------|
| `radio` | Radio list | `tui_radio_list()` (tui.sh:1445) |
| `text` | Text input | `tui_text_input()` (tui.sh:1789) |
| `yesno` | Yes/No dialog | `tui_yesno()` (tui.sh:1721) |

**Widget contracts (already established):**
- `tui_radio_list(title, subtitle, item1, item2, ...)` — returns 0-based index via stdout + TUI_RESULT
- `tui_text_input(title, prompt, [default])` — returns typed string via stdout + TUI_RESULT
- `tui_yesno(title, message, [default])` — returns 'yes'/'no' via stdout + TUI_RESULT

**Collection flow (D-09, D-10):**
```
for each param in metadata:
  case param.type:
    radio:  tui_radio_list "${param.name}" "Choose ${param.name}" "${param.choices[@]}"
    text:   tui_text_input "${param.name}" "Enter ${param.name}" "${param.default}"
    yesno:  tui_yesno "${param.name}" "${param.message}" "${param.default}"
  collect value → build args array
```

**Arg passing (D-10):**
```sh
# Values collected become --key value pairs
sh -s -- --scope global --name "My Project"
```

On cancellation (user presses Esc at any param): abort module execution, return to menu.

### 4. Platform Context

**Pattern (D-11):** Reuse and adapt fu.sh detection patterns for POSIX sh.

```sh
flu_module_set_env() {
  # Platform detection (adapted from fu.sh for POSIX sh compatibility)
  _os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$_os" in
    linux*)  FLU_OS="linux" ;;
    darwin*) FLU_OS="darwin" ;;
    *)       FLU_OS="linux" ;;
  esac

  # Distro detection
  if [ -f /etc/os-release ]; then
    FLU_DISTRO=$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-linux}")
  else
    FLU_DISTRO="linux"
  fi

  # Package manager
  FLU_PKG_MGR=$(_flu_detect_pkg_mgr)

  # Architecture
  FLU_ARCH=$(uname -m)

  # WSL detection
  if grep -qi "microsoft" /proc/version 2>/dev/null; then
    FLU_IS_WSL="1"
  else
    FLU_IS_WSL="0"
  fi

  # Termux detection
  if [ -n "${TERMUX_VERSION:-}" ] || [ -d /data/data/com.termux ]; then
    FLU_IS_TERMUX="1"
  else
    FLU_IS_TERMUX="0"
  fi

  # Root detection
  if [ "$(id -u)" -eq 0 ]; then
    FLU_IS_ROOT="1"
  else
    FLU_IS_ROOT="0"
  fi

  export FLU_OS FLU_DISTRO FLU_PKG_MGR FLU_ARCH FLU_IS_WSL FLU_IS_TERMUX FLU_IS_ROOT
}
```

### 5. Execution Environment

**Isolation (D-14):**
```sh
fl_module_execute() {
  _url=$1; shift
  _timeout=${1:-300}

  # Fetch -> pipe -> execute in subshell
  (
    set -euo pipefail
    trap 'exit_code=$?; trap - EXIT; exit $exit_code' EXIT
    curl -fsSL "$_url" | sh -s -- "$@"
  )
  _rc=$?
  return $_rc
}
```

**Timeout (D-15):**
- Use `timeout` command when available (GNU coreutils, BusyBox)
- Fallback: background process + `wait` with time limit
```sh
_flu_execute_with_timeout() {
  _timeout=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$_timeout" sh -s -- "$@"
  else
    # Fallback: background + kill on timeout
    sh -s -- "$@" &
    _pid=$!
    (
      sleep "$_timeout"
      kill "$_pid" 2>/dev/null
    ) &
    _watchdog=$!
    wait "$_pid" 2>/dev/null
    _rc=$?
    kill "$_watchdog" 2>/dev/null
    wait "$_watchdog" 2>/dev/null
    return $_rc
  fi
}
```

### 6. Result Display

**Pattern (D-12, D-13):** Box-rendered modal reusing `_tui_draw_box()` from tui.sh.

```sh
flu_module_display_result() {
  _status=$1; _output=$2; _module_name=$3
  tui_init
  clear_screen

  # Box with status-colored title
  _rows=$(tput lines 2>/dev/null || printf '24')
  _cols=$(tput cols 2>/dev/null || printf '80')
  _box_w=70; _box_h=$((_rows - 4))
  _x=$(( (_cols - _box_w) / 2 )); [ "$_x" -lt 1 ] && _x=1
  _y=2

  if [ "$_status" = "success" ]; then
    _title="✓ ${_module_name} — Complete"
  else
    _title="✗ ${_module_name} — Failed"
  fi
  _tui_draw_box "$_x" "$_y" "$_box_w" "$_box_h" "$_title"

  # Render output content inside box
  # ... output lines with word-wrap ...
  
  # Recovery hints on failure (D-13)
  if [ "$_status" != "success" ]; then
    _flu_display_recovery_hints "$_exit_code" "$_output"
  fi

  # "Press any key to continue" footer
  # ... wait for key ...
  tui_restore
}
```

### 7. File Structure

Following the Phase 1-3 pattern of single-file source+function API:

```
modules.sh         # Module architecture library (sourceable)
├── flu_module_fetch(action_id)          # Fetch + parse metadata
├── flu_module_parse_metadata()          # awk-based @key parser
├── flu_module_resolve_url(action_id)    # Action ID → GitHub URL
├── _flu_parse_params(param_string)      # Parse param declarations
├── flu_module_collect_params(params)    # Prompt user for each param
├── flu_module_set_env()                 # Set platform context env vars
├── flu_module_execute(action_id)        # Orchestrate: fetch→prompt→execute
├── flu_module_display_result()          # Box modal with result
└── _flu_module_show_err()              # Error display with recovery hints
```

### 8. POSIX Compatibility

All code must pass `shellcheck -s sh`. Key constraints from CONCERNS.md:
- NO `$'\033'` → use `printf '\033'` (already in tui.sh as `ESC`)
- NO `echo -e` → use `printf`
- NO `[[ ]]` → use `[ ]` with proper quoting
- NO `${var:0:1}` substring → use `awk` or `printf '%s' "$var" | cut`
- NO `local` keyword → use global variables with `_` prefix
- NO bash arrays → use eval-assigned numbered globals (`_fmp_name_1`, etc.)

## Validation Architecture

### Testability

Each function in modules.sh has clearly defined inputs and outputs:

| Function | Input | Output | Test Method |
|----------|-------|--------|-------------|
| `flu_module_parse_metadata` | stdin (script content) | stdout (metadata fields) | Pipe test fixture, grep for expected values |
| `flu_module_resolve_url` | action_id string | stdout (URL string) | Call with known ID, verify URL pattern |
| `_flu_parse_params` | param declaration string | stdout (parsed rows) | Feed test string, count output rows |
| `flu_module_collect_params` | param rows | stdout (collected values) | Mock widget results, verify arg flags |
| `flu_module_set_env` | (none — detects system) | exported env vars | Call then check `$FLU_OS`, `$FLU_ARCH` |

### Test Fixtures

Sample module for testing:
```sh
#!/usr/bin/env sh
# @name: Test Module
# @params: scope=radio:global,user;name=text
# @platforms: linux,darwin
# @version: 0.1.0
# @deps: 
# @timeout: 10

echo "Running test module on $FLU_OS"
echo "Scope: ${1:-default}"
echo "Name: ${2:-unnamed}"
exit 0
```

## Integration Points

### Consumes (from prior phases):
- `tui_init`/`tui_restore` (terminal management)
- `_tui_read_key` (key input)
- `tui_radio` (single-select parameter prompt)
- `tui_text_input` (text parameter prompt)
- `tui_yesno` (confirmation parameter prompt)
- `_tui_draw_box` (box rendering for result display)
- `clear_screen` / `move_cursor` (screen management)
- `flu_menu_get_action` (receives action ID from menu)

### Produces (for Phase 5):
- `flu_module_execute(action_id)` — main entry point for orchestrator
- `modules.sh` — sourceable library

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| curl unavailable on minimal systems | Low | Medium | wget fallback implemented |
| Pipe exit code not propagating | Medium | High | `set -o pipefail` + explicit capture |
| Timeout kills parent shell | Low | High | Always run in subshell `( ... )` |
| Module script has bashisms | Medium | Medium | Document module authoring guide; modules are external |
| Metadata parse breaks on edge cases | Low | Medium | Test with malformed headers, empty fields, special chars |
| Parameter prompt cancellation state leak | Low | Low | Reset TUI_RESULT after each widget call |

## References

- `fu.sh:139-155` — retry_network() pattern
- `fu.sh:160-321` — platform detection layer
- `tui.sh:1721-1777` — tui_yesno() widget contract
- `tui.sh:1789-2146` — tui_text_input() widget contract
- `tui.sh:1445-1599` — tui_radio() widget contract
- `tui.sh:503-551` — _tui_draw_box() rendering primitive
- `menu.sh:270-292` — flu_menu_get_action() output format
- `.planning/codebase/CONCERNS.md` — POSIX anti-patterns
- `.planning/codebase/CONVENTIONS.md` — naming conventions
