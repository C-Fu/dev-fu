#!/usr/bin/env sh
# ============================================================
# flu.sh — Modular TUI Menu System
# ============================================================
# Description: A zero-dependency, curl-pipe-bash-ready TUI menu
#   that fetches and executes modular install scripts on demand.
#   Coexists with fu.sh — both are independent scripts.
# Compatibility: bash, zsh, dash, ash, busybox sh
# Branch: flu.sh (development), merged to main when stable
# ============================================================

# ──────────────
# 📡 TTY Reattachment (for curl | bash)
# ──────────────
# If stdin is not a TTY (e.g., curl-pipe-bash), reattach to /dev/tty
# so interactive TUI menus work correctly.
# If /dev/tty is unavailable, fall through to numbered prompt fallback.
if [ ! -t 0 ] && [ -r /dev/tty ]; then
    exec 0</dev/tty
fi

# ──────────────
# 📦 Subsystem Sourcing
# ──────────────
# Resolve script location for sourcing sibling files
FLU_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Source subsystems in dependency order (D-01):
#   tui.sh first (defines TUI_RESET and rendering primitives)
#   menu.sh second (checks for TUI_RESET, sources tui.sh if absent)
#   modules.sh third (checks for TUI_RESET, sources tui.sh if absent)
# shellcheck disable=SC1091
. "$FLU_SCRIPT_DIR/tui.sh"
# shellcheck disable=SC1091
. "$FLU_SCRIPT_DIR/menu.sh"
# shellcheck disable=SC1091
. "$FLU_SCRIPT_DIR/modules.sh"

# ──────────────
# 🛡 Signal-Safe Cleanup
# ──────────────
# Orchestrator-level safety net: ensures terminal is always restored
# on every exit path (normal, error, or signal).
# Subsystems (tui.sh, menu.sh, modules.sh) set their own traps during
# TUI operations, but this trap covers gaps between TUI sessions.
_flu_cleanup_exit() {
    # Kill any spinner process
    flu_spinner_stop 2>/dev/null || true

    # Force terminal back to sane cooked mode on every signal
    stty sane 2>/dev/null < /dev/tty || true
    tui_restore 2>/dev/null || true

    printf '\nflu.sh — Goodbye!\n'
    exit 130
}

# Register traps for common termination signals
# INT  (2)  — Ctrl-C
# TERM (15) — kill (default)
# HUP  (1)  — terminal closed / SSH disconnected
# QUIT (3)  — Ctrl-\ (core dump signal)
trap '_flu_cleanup_exit' INT TERM HUP QUIT

# ──────────────
# 🔍 Platform Detection
# ──────────────
# Detect OS, distro, package manager, architecture via modules.sh
# Sets and exports: FLU_OS FLU_DISTRO FLU_PKG_MGR FLU_ARCH
#   FLU_IS_WSL FLU_IS_TERMUX FLU_IS_ROOT
flu_module_set_env

# ──────────────
# 🎨 Logo Art — ASCII "dev-fu" LEGO-style block characters
# ──────────────
# Renders the branded dev-fu logo centered on screen.
# Uses TUI_MAGENTA for color matching fu.sh branding.
# Logo is 6 lines tall, ~62 chars wide (including border chars).
# Requires: tui_init() already called, _tui_use_tui=true.
_flu_render_logo() {
    # Get terminal dimensions
    _flu_logo_cols=$(tput cols 2>/dev/null || printf '80')
    _flu_logo_rows=$(tput lines 2>/dev/null || printf '24')

    # Logo width: 60 characters of visual content
    _flu_logo_width=60
    _flu_logo_start_col=$(( (_flu_logo_cols - _flu_logo_width) / 2 ))
    # Ensure minimum column of 1
    [ "$_flu_logo_start_col" -lt 1 ] && _flu_logo_start_col=1

    # Position logo: start at row 1-3 for visual centering
    # If terminal is short, start at row 1; otherwise center vertically
    _flu_logo_start_row=$(( (_flu_logo_rows - 6) / 3 ))
    [ "$_flu_logo_start_row" -lt 1 ] && _flu_logo_start_row=1

    # Render each line of the logo using _tui_printf_at
    # Each line is left-trimmed of its leading whitespace from fu.sh,
    # so we rely on _flu_logo_start_col for horizontal centering.
    _flu_logo_row=$_flu_logo_start_row

    # Line 1: "    ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s    ██╗ ██╗██████╗ ███████╗██╗   ██╗      ███████╗██╗   ██╗%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    _flu_logo_row=$((_flu_logo_row + 1))
    # Line 2: "██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s██╗   ██╔╝██╔╝██╔══██╗██╔════╝██║   ██║      ██╔════╝██║   ██║%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    _flu_logo_row=$((_flu_logo_row + 1))
    # Line 3: "╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s╚═╝  ██╔╝██╔╝ ██║  ██║█████╗  ██║   ██║█████╗█████╗  ██║   ██║%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    _flu_logo_row=$((_flu_logo_row + 1))
    # Line 4: "██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s██╗ ██╔╝██╔╝  ██║  ██║██╔══╝  ╚██╗ ██╔╝╚════╝██╔══╝  ██║   ██║%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    _flu_logo_row=$((_flu_logo_row + 1))
    # Line 5: "╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s╚═╝██╔╝██╔╝   ██████╔╝███████╗ ╚████╔╝       ██║     ╚██████╔╝%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    _flu_logo_row=$((_flu_logo_row + 1))
    # Line 6: "    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝"
    # shellcheck disable=SC2059
    _tui_printf_at "$_flu_logo_row" "$_flu_logo_start_col" \
        "%s    ╚═╝ ╚═╝    ╚═════╝ ╚══════╝  ╚═══╝        ╚═╝      ╚═════╝%s" \
        "$TUI_MAGENTA" "$TUI_RESET"

    # Cleanup locals
    unset _flu_logo_cols _flu_logo_rows _flu_logo_width _flu_logo_start_col
    unset _flu_logo_start_row _flu_logo_row
}

# ──────────────
# 🖥 Startup Platform Display
# ──────────────
# Show detected platform info before entering menu
# shellcheck disable=SC2154
if [ "$_tui_use_tui" = "true" ]; then
    tui_init
    clear_screen

    # Render the ASCII dev-fu logo centered on screen (POLISH-01)
    _flu_render_logo

    # Calculate centered positions — note: logo is 6 lines tall,
    # so the platform box starts below the logo with a small gap
    _flu_su_cols=$(tput cols 2>/dev/null || printf '80')
    _flu_su_rows=$(tput lines 2>/dev/null || printf '24')
    _flu_su_box_w=50
    [ "$_flu_su_box_w" -gt "$_flu_su_cols" ] && _flu_su_box_w=$((_flu_su_cols - 4))
    _flu_su_box_x=$(( (_flu_su_cols - _flu_su_box_w) / 2 ))
    [ "$_flu_su_box_x" -lt 1 ] && _flu_su_box_x=1
    # Box starts 7 lines below top (6 logo lines + 1 line gap)
    _flu_su_box_y=7
    # If terminal is short, push box down a bit more for visual balance
    # on very tall terminals, keep it closer to the logo
    [ "$_flu_su_rows" -lt 20 ] && _flu_su_box_y=7

    # Build platform info lines
    _flu_su_os_info="OS: ${FLU_OS}"
    _flu_su_distro_info="Distro: ${FLU_DISTRO}"
    _flu_su_pkg_info="Package Manager: ${FLU_PKG_MGR}"
    _flu_su_arch_info="Architecture: ${FLU_ARCH}"

    # Draw the box
    _tui_draw_box "$_flu_su_box_x" "$_flu_su_box_y" "$_flu_su_box_w" 9 \
        "${TUI_CYAN}flu.sh v0.1.0${TUI_RESET}"

    # Render platform details inside the box
    _flu_su_inner_x=$((_flu_su_box_x + 3))
    _flu_su_row=$((_flu_su_box_y + 3))

    _tui_printf_at "$_flu_su_row" "$_flu_su_inner_x" \
        "%s%s%s" "$TUI_BOLD" "$_flu_su_os_info" "$TUI_RESET"

    _flu_su_row=$((_flu_su_row + 1))
    _tui_printf_at "$_flu_su_row" "$_flu_su_inner_x" \
        "%s%s%s" "$TUI_GREEN" "$_flu_su_distro_info" "$TUI_RESET"

    _flu_su_row=$((_flu_su_row + 1))
    _tui_printf_at "$_flu_su_row" "$_flu_su_inner_x" \
        "%s%s%s" "$TUI_YELLOW" "$_flu_su_pkg_info" "$TUI_RESET"

    _flu_su_row=$((_flu_su_row + 1))
    _tui_printf_at "$_flu_su_row" "$_flu_su_inner_x" \
        "%s%s%s" "$TUI_CYAN" "$_flu_su_arch_info" "$TUI_RESET"

    # Footer: "Press any key to continue"
    _flu_su_footer_row=$((_flu_su_box_y + 7))
    _tui_printf_at "$_flu_su_footer_row" "$_flu_su_inner_x" \
        "%sPress any key to continue...%s" "$TUI_DIM" "$TUI_RESET"

    # Wait for keypress
    _tui_read_key

    tui_restore
    # Re-register orchestrator safety-net trap (overwritten by tui_init)
    trap '_flu_cleanup_exit' INT TERM HUP QUIT
else
    # Non-TUI: print logo in plain text (no ANSI colors — terminal may not support)
    printf '%s\n' "=============================================="
    printf '%s\n' "  dev-fu — Environment Setup Utility"
    printf '%s\n' "=============================================="
    printf '\n'
    printf 'flu.sh v0.1.0\n'
    printf 'OS: %s | Distro: %s | Package Manager: %s | Arch: %s\n\n' \
        "$FLU_OS" "$FLU_DISTRO" "$FLU_PKG_MGR" "$FLU_ARCH"
fi

# Cleanup startup display locals
unset _flu_su_cols _flu_su_rows _flu_su_box_w _flu_su_box_x _flu_su_box_y
unset _flu_su_inner_x _flu_su_row _flu_su_footer_row
unset _flu_su_os_info _flu_su_distro_info _flu_su_pkg_info _flu_su_arch_info

# ──────────────
# 🩺 Error Recovery Mapping
# ──────────────
# Maps exit codes from flu_module_execute to actionable user hints.
# Called after module execution in the main loop.
# Each hint tells the user WHAT to do, not just what failed.
_flu_map_exit_code() {
    _fmec_code=$1
    _fmec_action=$2

    case "$_fmec_code" in
        0)
            # Success — no recovery hint needed
            ;;
        124)
            printf '%s⏱ Timeout: The operation took too long.%s\n' \
                "$TUI_YELLOW" "$TUI_RESET"
            printf '%s   → Try again. If the issue persists, check your network speed or run during off-peak hours.%s\n' \
                "$TUI_DIM" "$TUI_RESET"
            ;;
        126)
            printf '%s🔒 Permission denied: The module script could not be executed.%s\n' \
                "$TUI_YELLOW" "$TUI_RESET"
            printf '%s   → This may indicate a corrupted download. Try running the operation again.%s\n' \
                "$TUI_DIM" "$TUI_RESET"
            ;;
        127)
            printf '%s❓ Command not found: A required dependency is missing.%s\n' \
                "$TUI_YELLOW" "$TUI_RESET"
            printf '%s   → Ensure all dependencies for "%s" are installed before retrying.%s\n' \
                "$TUI_DIM" "$_fmec_action" "$TUI_RESET"
            ;;
        1)
            # Generic failure — check if it was a fetch failure or module error
            printf '%s✗ Operation failed (exit code 1).%s\n' \
                "$TUI_RED" "$TUI_RESET"
            printf '%s   → Check your internet connection if this was a network operation.%s\n' \
                "$TUI_DIM" "$TUI_RESET"
            printf '%s   → Try running the operation again.%s\n' \
                "$TUI_DIM" "$TUI_RESET"
            ;;
        *)
            printf '%s✗ Operation exited with code %d.%s\n' \
                "$TUI_RED" "$_fmec_code" "$TUI_RESET"
            printf '%s   → An unexpected error occurred. Try running the operation again.%s\n' \
                "$TUI_DIM" "$TUI_RESET"
            ;;
    esac

    unset _fmec_code _fmec_action
}

# ──────────────
# 📋 Menu Definition
# ──────────────
FLU_MENU_FILE="$FLU_SCRIPT_DIR/menu.db"

# Verify menu file exists
if [ ! -f "$FLU_MENU_FILE" ]; then
    printf '%sError: menu definition not found: %s%s\n' \
        "$TUI_RED" "$FLU_MENU_FILE" "$TUI_RESET" >&2
    exit 1
fi

# ──────────────
# 🔄 Main Event Loop
# ──────────────

# Track module execution for flow control
_flu_running=true

while [ "$_flu_running" = "true" ]; do
    # --- Step 1: Menu Navigation ---
    # flu_menu_navigate() handles its own TUI lifecycle:
    #   - Calls tui_init() internally
    #   - Renders menu levels, handles keyboard input
    #   - Calls tui_restore() on exit (cancel at root) or
    #     before returning (leaf select)
    # Returns 0 on leaf selection (TUI_RESULT set to "L1|L2|L3" path)
    # Returns 1 on cancel at root level
    flu_menu_navigate "$FLU_MENU_FILE"
    _flu_nav_rc=$?

    if [ "$_flu_nav_rc" -ne 0 ]; then
        # User cancelled at root — exit cleanly
        _flu_running=false
        continue
    fi

    # --- Step 2: Extract Action ID(s) ---
    # shellcheck disable=SC2154
    if [ -n "${TUI_QUEUE:-}" ]; then
        _flu_actions=$TUI_QUEUE
    else
        _flu_action=$(flu_menu_get_action "$TUI_RESULT")
        if [ -z "$_flu_action" ]; then
            continue
        fi
        _flu_actions=$_flu_action
    fi

    # --- Step 3: Module Execution ---
    trap '_flu_cleanup_exit' INT TERM HUP QUIT
    printf '\033[?25l'
    for _flu_action in $_flu_actions; do
        printf '\n  Running %s...\n' "$_flu_action"
        flu_module_execute "$_flu_action"
        _flu_mod_rc=$?
        if [ "$_flu_mod_rc" -ne 0 ]; then
            _flu_map_exit_code "$_flu_mod_rc" "$_flu_action"
            printf '\n%sPress any key to continue%s' "$TUI_DIM" "$TUI_RESET"
            _tui_read_key
        fi
    done
    unset _flu_actions

    # --- Step 4: Post-Execution ---
    clear_screen
    # Re-register orchestrator safety-net trap
    trap '_flu_cleanup_exit' INT TERM HUP QUIT
done

# --- Step 5: Clean Exit ---
tui_restore
printf '%sflu.sh — Goodbye!%s\n' "$TUI_GREEN" "$TUI_RESET"

# Cleanup globals
unset _flu_action _flu_nav_rc _flu_mod_rc _flu_running
unset FLU_SCRIPT_DIR FLU_MENU_FILE
