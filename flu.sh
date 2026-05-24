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
# 🔍 Platform Detection
# ──────────────
# Detect OS, distro, package manager, architecture via modules.sh
# Sets and exports: FLU_OS FLU_DISTRO FLU_PKG_MGR FLU_ARCH
#   FLU_IS_WSL FLU_IS_TERMUX FLU_IS_ROOT
flu_module_set_env

# ──────────────
# 🖥 Startup Platform Display
# ──────────────
# Show detected platform info before entering menu
# shellcheck disable=SC2154
if [ "$_tui_use_tui" = "true" ]; then
    tui_init
    clear_screen

    # Calculate centered positions
    _flu_su_cols=$(tput cols 2>/dev/null || printf '80')
    _flu_su_rows=$(tput lines 2>/dev/null || printf '24')
    _flu_su_box_w=50
    [ "$_flu_su_box_w" -gt "$_flu_su_cols" ] && _flu_su_box_w=$((_flu_su_cols - 4))
    _flu_su_box_x=$(( (_flu_su_cols - _flu_su_box_w) / 2 ))
    [ "$_flu_su_box_x" -lt 1 ] && _flu_su_box_x=1
    _flu_su_box_y=$(( (_flu_su_rows - 9) / 2 ))
    [ "$_flu_su_box_y" -lt 1 ] && _flu_su_box_y=1

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
else
    # Non-TUI: print plain text platform summary
    printf 'flu.sh v0.1.0\n'
    printf 'OS: %s | Distro: %s | Package Manager: %s | Arch: %s\n\n' \
        "$FLU_OS" "$FLU_DISTRO" "$FLU_PKG_MGR" "$FLU_ARCH"
fi

# Cleanup startup display locals
unset _flu_su_cols _flu_su_rows _flu_su_box_w _flu_su_box_x _flu_su_box_y
unset _flu_su_inner_x _flu_su_row _flu_su_footer_row
unset _flu_su_os_info _flu_su_distro_info _flu_su_pkg_info _flu_su_arch_info

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

    # --- Step 2: Extract Action ID ---
    # TUI_RESULT is set by flu_menu_navigate on leaf selection
    # Example: "Developer Tools|Languages|Python"
    # flu_menu_get_action extracts the action field from menu.db
    # shellcheck disable=SC2154
    _flu_action=$(flu_menu_get_action "$TUI_RESULT")

    if [ -z "$_flu_action" ]; then
        # No action defined for this path — edge case, return to menu
        continue
    fi

    # --- Step 3: Module Execution with Spinner (INTG-01, D-05) ---
    # Start the spinner BEFORE flu_module_execute so it's visible
    # during the network fetch phase (flu_module_fetch uses curl/wget).
    # The spinner renders via background process.
    # flu_module_execute internally:
    #   1. flu_module_fetch() — network call (spinner visible)
    #   2. flu_module_parse_metadata()
    #   3. flu_module_set_env()
    #   4. Platform compatibility check
    #   5. flu_module_collect_params() — TUI prompts
    #   6. Execute module in subshell
    #   7. flu_module_display_result() — TUI modal
    # After flu_module_display_result, tui_restore() is called
    # internally, returning terminal to cooked mode.
    flu_spinner_start
    flu_module_execute "$_flu_action"
    _flu_mod_rc=$?
    flu_spinner_stop

    # --- Step 4: Post-Execution ---
    # Clear screen to prepare for fresh menu render on next iteration
    clear_screen

    # _flu_mod_rc is preserved but not used here — error recovery
    # is handled in Plan 05-03 (error mapping).
done

# --- Step 5: Clean Exit ---
tui_restore
printf '%sflu.sh — Goodbye!%s\n' "$TUI_GREEN" "$TUI_RESET"

# Cleanup globals
unset _flu_action _flu_nav_rc _flu_mod_rc _flu_running
unset FLU_SCRIPT_DIR FLU_MENU_FILE
