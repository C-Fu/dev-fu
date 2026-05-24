#!/usr/bin/env sh
# test_spinner.sh — Test harness for flu_spinner_start / flu_spinner_stop
#
# Tests the functional behavior of the spinner widget: process creation,
# cleanup, idempotent guard, and zombie prevention.
# Completely portable POSIX sh. No external test framework.

. ./tui.sh

PASSES=0
FAILURES=0

# Force non-TUI mode for deterministic test output
_tui_use_tui=false

assert_eq() {
    _desc="$1"
    _expected="$2"
    _actual="$3"
    if [ "$_expected" = "$_actual" ]; then
        PASSES=$((PASSES + 1))
        printf 'PASS: %s\n' "$_desc"
    else
        FAILURES=$((FAILURES + 1))
        printf 'FAIL: %s\n' "$_desc"
        printf '  expected: <%s>\n' "$_expected"
        printf '  actual:   <%s>\n' "$_actual"
    fi
    unset _desc _expected _actual
}

assert_nempty() {
    _desc="$1"
    _val="$2"
    if [ -n "$_val" ]; then
        PASSES=$((PASSES + 1))
        printf 'PASS: %s\n' "$_desc"
    else
        FAILURES=$((FAILURES + 1))
        printf 'FAIL: %s (empty)\n' "$_desc"
    fi
    unset _desc _val
}

printf '\n========================================\n'
printf '  Spinner Widget Tests\n'
printf '========================================\n\n'

# ---------------------------------------------------------
# Test 1: flu_spinner_start() creates a background process
# ---------------------------------------------------------
_flu_spinner_pid=''
flu_spinner_start
_pid="${_flu_spinner_pid:-}"
assert_nempty "flu_spinner_start sets _flu_spinner_pid" "$_pid"

if [ -n "$_pid" ]; then
    if kill -0 "$_pid" 2>/dev/null; then
        assert_eq "Background process is alive after start" "alive" "alive"
    else
        assert_eq "Background process is alive after start" "alive" "dead"
    fi
else
    assert_eq "Background process is alive after start" "alive" "no-pid"
fi
flu_spinner_stop

# ---------------------------------------------------------
# Test 2: flu_spinner_start is idempotent (guard)
# ---------------------------------------------------------
_flu_spinner_pid=''
flu_spinner_start
_first_pid="${_flu_spinner_pid}"
flu_spinner_start
_second_pid="${_flu_spinner_pid}"
assert_eq "flu_spinner_start guard: second call returns same PID" "$_first_pid" "$_second_pid"
flu_spinner_stop

# ---------------------------------------------------------
# Test 3: flu_spinner_stop() clears PID and kills process
# ---------------------------------------------------------
_flu_spinner_pid=''
flu_spinner_start
_stop_pid="${_flu_spinner_pid}"
flu_spinner_stop
# Give the process a moment to terminate
sleep 0.3

assert_eq "flu_spinner_stop clears _flu_spinner_pid" "" "${_flu_spinner_pid:-}"
if [ -n "$_stop_pid" ]; then
    if kill -0 "$_stop_pid" 2>/dev/null; then
        assert_eq "Background process is dead after stop" "dead" "alive"
    else
        assert_eq "Background process is dead after stop" "dead" "dead"
    fi
else
    assert_eq "Background process is dead after stop" "dead" "no-pid"
fi
unset _stop_pid

# ---------------------------------------------------------
# Test 4: flu_spinner_stop() is safe when no spinner running
# ---------------------------------------------------------
_flu_spinner_pid=''
_rc=0
flu_spinner_stop 2>/dev/null || _rc=$?
assert_eq "flu_spinner_stop no-op safe (no crash)" "0" "$_rc"
assert_eq "flu_spinner_stop no-op keeps pid empty" "" "${_flu_spinner_pid:-}"

# ---------------------------------------------------------
# Test 5: Multiple start/stop cycles work cleanly
# ---------------------------------------------------------
_cycle_ok=true
for _i in 1 2 3; do
    _flu_spinner_pid=''
    flu_spinner_start
    if [ -z "${_flu_spinner_pid:-}" ]; then
        _cycle_ok=false
        break
    fi
    flu_spinner_stop
    sleep 0.2
    if [ -n "${_flu_spinner_pid:-}" ]; then
        _cycle_ok=false
        break
    fi
done
if [ "$_cycle_ok" = "true" ]; then
    assert_eq "Multiple start/stop cycles clean" "ok" "ok"
else
    assert_eq "Multiple start/stop cycles clean" "ok" "fail"
fi
unset _i _cycle_ok

# ---------------------------------------------------------
# Test 6: _flu_spinner_render exists and runs without error
# ---------------------------------------------------------
_flu_spinner_frame=0
if command -v _flu_spinner_render >/dev/null 2>&1; then
    _rc=0
    _flu_spinner_render >/dev/null 2>&1 || _rc=$?
    assert_eq "_flu_spinner_render runs without error" "0" "$_rc"
    assert_eq "_flu_spinner_render increments frame counter" "0" \
      "$( [ "$_flu_spinner_frame" -gt 0 ] && printf '0' || printf '1' )"
else
    assert_eq "_flu_spinner_render exists" "exists" "missing"
fi

printf '\n========================================\n'
printf '  Results: %d passed, %d failed\n' "$PASSES" "$FAILURES"
printf '========================================\n\n'

exit $FAILURES
