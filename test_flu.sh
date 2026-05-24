#!/usr/bin/env sh
# test_flu.sh — Structural tests for flu.sh orchestrator
#
# Run: sh test_flu.sh
# Exit 0 = all tests pass, exit 1 = one or more tests fail
#
# No external dependencies.

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# ──────────────
# Test runner helpers
# ──────────────

_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    printf '  ✓ %s\n' "$1"
}

_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    printf '  ✗ %s\n' "$1" >&2
}

_assert() {
    _a_desc="$1"
    shift
    if "$@"; then
        _pass "$_a_desc"
    else
        _fail "$_a_desc"
    fi
}

_assert_grep() {
    _ag_desc="$1"
    _ag_pattern="$2"
    _ag_file="$3"
    if grep -q "$_ag_pattern" "$_ag_file" 2>/dev/null; then
        _pass "$_ag_desc"
    else
        _fail "$_ag_desc (pattern not found: $_ag_pattern)"
    fi
}

_assert_grep_count() {
    _agc_desc="$1"
    _agc_count="$2"
    _agc_pattern="$3"
    _agc_file="$4"
    _agc_actual=$(grep -c "$_agc_pattern" "$_agc_file" 2>/dev/null)
    _agc_actual="${_agc_actual:-0}"
    if [ "$_agc_actual" -eq "$_agc_count" ]; then
        _pass "$_agc_desc"
    else
        _fail "$_agc_desc (expected $_agc_count, found $_agc_actual)"
    fi
}

_assert_not_grep() {
    _ang_desc="$1"
    _ang_pattern="$2"
    _ang_file="$3"
    if ! grep -q "$_ang_pattern" "$_ang_file" 2>/dev/null; then
        _pass "$_ang_desc"
    else
        _fail "$_ang_desc (forbidden pattern found: $_ang_pattern)"
    fi
}

# ──────────────
# Task 1: flu.sh skeleton
# ──────────────

echo ""
echo "=== Task 1: flu.sh Skeleton ==="
echo ""

_assert "flu.sh exists" test -f "./flu.sh"

if [ -f "./flu.sh" ]; then

_assert "flu.sh has correct shebang" \
    test "$(head -n1 ./flu.sh)" = "#!/usr/bin/env sh"

_assert "flu.sh is valid shell syntax" \
    sh -n ./flu.sh

_assert_grep "flu.sh contains TTY reattachment" \
    "exec 0</dev/tty" "./flu.sh"

_assert_grep "flu.sh sources tui.sh" \
    '\. "\$FLU_SCRIPT_DIR/tui.sh"' "./flu.sh"

_assert_grep "flu.sh sources menu.sh" \
    '\. "\$FLU_SCRIPT_DIR/menu.sh"' "./flu.sh"

_assert_grep "flu.sh sources modules.sh" \
    '\. "\$FLU_SCRIPT_DIR/modules.sh"' "./flu.sh"

_assert_grep "flu.sh calls flu_module_set_env" \
    "flu_module_set_env" "./flu.sh"

_assert_grep "flu.sh defines FLU_MENU_FILE" \
    "FLU_MENU_FILE" "./flu.sh"

_assert_grep "flu.sh has FLU_SCRIPT_DIR" \
    'FLU_SCRIPT_DIR=' "./flu.sh"

# Anti-pattern checks: no bashisms
_assert_not_grep "flu.sh has no \$'\''\033'\'' bashism" \
    "\\$'\\\\033'" "./flu.sh"

_assert_not_grep "flu.sh has no echo -e bashism" \
    "echo -e" "./flu.sh"

_assert_not_grep "flu.sh has no sed \\\\x1b pattern" \
    "sed '.*\\\\x1b" "./flu.sh"

_assert_not_grep "flu.sh has no double-bracket test \[\[" \
    '\[\[' "./flu.sh"

# Verify TTY reattachment count is exactly 1
_assert_grep_count "flu.sh has exactly 1 TTY reattachment" \
    "1" 'exec 0</dev/tty' "./flu.sh"

# ──────────────
# Task 2: Main event loop
# ──────────────

echo ""
echo "=== Task 2: Main Event Loop ==="
echo ""

_assert_grep "flu.sh calls flu_menu_navigate" \
    "flu_menu_navigate" "./flu.sh"

_assert_grep "flu.sh calls flu_menu_get_action" \
    "flu_menu_get_action" "./flu.sh"

_assert_grep "flu.sh calls flu_spinner_start" \
    "flu_spinner_start" "./flu.sh"

_assert_grep "flu.sh calls flu_module_execute" \
    "flu_module_execute" "./flu.sh"

_assert_grep "flu.sh calls flu_spinner_stop" \
    "flu_spinner_stop" "./flu.sh"

_assert_grep "flu.sh has _flu_running variable" \
    "_flu_running" "./flu.sh"

_assert_grep "flu.sh has TUI_RESULT usage" \
    "TUI_RESULT" "./flu.sh"

_assert_grep_count "flu.sh has exactly 1 flu_menu_navigate call" \
    "1" '^[^#]*flu_menu_navigate' "./flu.sh"

_assert_grep_count "flu.sh has exactly 1 flu_menu_get_action call" \
    "1" '^[^#]*flu_menu_get_action' "./flu.sh"

_assert_grep_count "flu.sh has exactly 1 flu_spinner_start call" \
    "1" '^[^#]*flu_spinner_start' "./flu.sh"

_assert_grep_count "flu.sh has exactly 1 flu_module_execute call" \
    "1" '^[^#]*flu_module_execute' "./flu.sh"

_assert_grep_count "flu.sh has exactly 1 flu_spinner_stop call" \
    "1" '^[^#]*flu_spinner_stop' "./flu.sh"

# Clean exit path
_assert_grep "flu.sh cleans up with tui_restore at exit" \
    "tui_restore" "./flu.sh"

# Loop structure check
_assert_grep "flu.sh has while loop" \
    "while" "./flu.sh"

_assert_grep "flu.sh has clear_screen call" \
    "clear_screen" "./flu.sh"

else
    echo "  (skipping remaining tests — flu.sh not found)"
fi

# ──────────────
# Summary
# ──────────────

echo ""
echo "=============================="
printf 'Results: %d passed, %d failed, %d total\n' \
    "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_TOTAL"
echo "=============================="

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
