# ============================================================
# tui.ps1 — PowerShell TUI Engine Foundation
#
# ANSI rendering primitives, terminal init/restore with PS
# version detection, keyboard input via [Console]::ReadKey(),
# and single-select menu widget with fallback.
#
# Port of the POSIX tui.sh to idiomatic PowerShell.
# Supports PowerShell 5.1 and PowerShell 7.
#
# Usage:
#   . .\tui.ps1
#   Initialize-Tui
#   # ... interactive TUI operations ...
#   Restore-Tui
# ============================================================

# ---------------------------------------------------------------------------
# Section 1: PS Version Detection and ANSI VT Enable
# ---------------------------------------------------------------------------

# D-05: Detect PowerShell version at module load time
$Script:FluPsVersion = $PSVersionTable.PSVersion

# D-04: Detect ANSI/VT support and enable on PS 5.1 if needed
$Script:FluAnsiSupported = $false
if ($Host.UI.SupportsVirtualTerminal) {
    $Script:FluAnsiSupported = $true
} else {
    # Attempt to enable VT processing on older PowerShell via P/Invoke
    try {
        $MethodDefinitions = @'
[DllImport("kernel32.dll", SetLastError = $true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = $true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = $true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        $Kernel32 = Add-Type -MemberDefinition $MethodDefinitions -Name 'Kernel32' -Namespace 'Win32' -PassThru
        $hConsoleHandle = $Kernel32::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        $mode = 0
        if ($Kernel32::GetConsoleMode($hConsoleHandle, [ref]$mode)) {
            $ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
            if ($Kernel32::SetConsoleMode($hConsoleHandle, $mode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING)) {
                $Script:FluAnsiSupported = $true
            }
        }
    } catch {
        # VT processing not available — ASCII fallback mode
    }
}
# Set [Console]::OutputEncoding for Unicode box drawing support
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ---------------------------------------------------------------------------
# Section 2: ANSI Escape Constants
# ---------------------------------------------------------------------------

$Script:ESC = [char]27
$Script:TUI_RESET = "$ESC[0m"
$Script:TUI_BOLD = "$ESC[1m"
$Script:TUI_DIM = "$ESC[2m"
$Script:TUI_REV = "$ESC[7m"
$Script:TUI_RED = "$ESC[31m"
$Script:TUI_GREEN = "$ESC[32m"
$Script:TUI_YELLOW = "$ESC[33m"
$Script:TUI_CYAN = "$ESC[36m"

# ---------------------------------------------------------------------------
# Section 3: Box Drawing Character Detection
# ---------------------------------------------------------------------------

# D-08: Detect UTF-8 vs ASCII box drawing characters matching tui.sh _tui_detect_box_chars()
$outputEncodingIsUtf8 = $false
try {
    $webName = [Console]::OutputEncoding.WebName
    $outputEncodingIsUtf8 = ($webName -match 'utf-?8')
} catch {}

if ($outputEncodingIsUtf8 -and $Script:FluAnsiSupported) {
    $Script:TUI_BOX_TL = '┌'; $Script:TUI_BOX_TR = '┐'
    $Script:TUI_BOX_BL = '└'; $Script:TUI_BOX_BR = '┘'
    $Script:TUI_BOX_H  = '─'; $Script:TUI_BOX_V  = '│'
} else {
    $Script:TUI_BOX_TL = '+'; $Script:TUI_BOX_TR = '+'
    $Script:TUI_BOX_BL = '+'; $Script:TUI_BOX_BR = '+'
    $Script:TUI_BOX_H  = '-'; $Script:TUI_BOX_V  = '|'
}

# ---------------------------------------------------------------------------
# Section 4: TTY / Terminal Availability Check
# ---------------------------------------------------------------------------

# _tui_use_tui equivalent — detect if TUI mode is possible
$Script:_tui_use_tui = $true
try {
    if ($Host.UI.RawUI.WindowSize.Height -lt 5) { $Script:_tui_use_tui = $false }
} catch {
    $Script:_tui_use_tui = $false
}
if ($env:TERM -eq 'dumb') { $Script:_tui_use_tui = $false }
# Equivalent of [ ! -t 0 ] check in POSIX
if ([Console]::IsInputRedirected) { $Script:_tui_use_tui = $false }

# ---------------------------------------------------------------------------
# Section 5: Terminal Init / Restore Functions
# ---------------------------------------------------------------------------

function Initialize-Tui {
    <#
    .SYNOPSIS
    Initialize terminal for TUI mode — hide cursor, enable raw key input.
    #>
    if (-not $Script:_tui_use_tui) { return }
    # Save cursor visibility state, hide cursor
    try {
        $Script:_tui_cursor_visible = [Console]::CursorVisible
        [Console]::CursorVisible = $false
    } catch {
        $Script:_tui_cursor_visible = $false
    }
    # Set Ctrl+C to be treated as input (not process kill)
    try {
        [Console]::TreatControlCAsInput = $true
        $Script:_tui_trap_set = $true
    } catch {
        $Script:_tui_trap_set = $false
    }
}

function Restore-Tui {
    <#
    .SYNOPSIS
    Restore terminal to normal state — show cursor, clear screen, restore key mode.
    #>
    try {
        [Console]::CursorVisible = $true
    } catch {}
    try {
        [Console]::TreatControlCAsInput = $false
    } catch {}
    Clear-TuiScreen
    Remove-Variable -Name '_tui_trap_set' -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name '_tui_cursor_visible' -Scope Script -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Section 6: Rendering Primitives
# ---------------------------------------------------------------------------

function Move-TuiCursor {
    <#
    .SYNOPSIS
    Move cursor to the specified row and column (1-based).
    #>
    param([int]$Row, [int]$Col)
    if ($Script:FluAnsiSupported) {
        Write-Host "$ESC[${Row};${Col}H" -NoNewline
    } else {
        try {
            [Console]::SetCursorPosition($Col - 1, $Row - 1)
        } catch {}
    }
}

function Clear-TuiScreen {
    <#
    .SYNOPSIS
    Clear the terminal screen and home the cursor.
    #>
    if ($Script:FluAnsiSupported) {
        Write-Host "$ESC[2J$ESC[H" -NoNewline
    } else {
        try {
            [Console]::Clear()
        } catch {}
    }
}

function Write-TuiAt {
    <#
    .SYNOPSIS
    Write text at a specific screen position without moving afterwards.
    #>
    param([int]$Row, [int]$Col, [string]$Text)
    Move-TuiCursor -Row $Row -Col $Col
    Write-Host $Text -NoNewline
}

# ---------------------------------------------------------------------------
# Section 7: Box Drawing Helper
# ---------------------------------------------------------------------------

function Write-TuiBox {
    <#
    .SYNOPSIS
    Draw a bordered box matching tui.sh _tui_draw_box() visual output.
    #>
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [string]$Title
    )

    $innerW = [Math]::Max(1, $Width - 2)
    $hLine = $Script:TUI_BOX_H * $innerW

    # Top border
    Move-TuiCursor -Row $Y -Col $X
    Write-Host "$($Script:TUI_BOX_TL)$hLine$($Script:TUI_BOX_TR)" -NoNewline

    # Title row
    Move-TuiCursor -Row ($Y + 1) -Col $X
    Write-Host $Script:TUI_BOX_V -NoNewline

    if ($Title) {
        # Strip ANSI sequences for length calculation
        $plainTitle = $Title -replace '\x1b\[[0-9;]*m', ''
        $titleLen = $plainTitle.Length
        $padLeft = [Math]::Max(0, [Math]::Floor(($innerW - $titleLen) / 2))
        $padRight = $innerW - $titleLen - $padLeft
        Write-Host (" " * [Math]::Max(0, $padLeft)) -NoNewline
        Write-Host "$($Script:TUI_BOLD)$Title$($Script:TUI_RESET)" -NoNewline
        Write-Host (" " * [Math]::Max(0, $padRight)) -NoNewline
    } else {
        Write-Host (" " * $innerW) -NoNewline
    }
    Write-Host $Script:TUI_BOX_V -NoNewline

    # Separator row below title
    Move-TuiCursor -Row ($Y + 2) -Col $X
    Write-Host $Script:TUI_BOX_V -NoNewline
    Write-Host ($Script:TUI_BOX_H * $innerW) -NoNewline
    Write-Host $Script:TUI_BOX_V -NoNewline

    # Body rows (Height - 4 border/title/separator rows)
    $bodyStart = $Y + 3
    $bodyEnd = $Y + $Height - 2
    for ($r = $bodyStart; $r -lt $bodyEnd; $r++) {
        Move-TuiCursor -Row $r -Col $X
        Write-Host $Script:TUI_BOX_V -NoNewline
        Write-Host (" " * $innerW) -NoNewline
        Write-Host $Script:TUI_BOX_V -NoNewline
    }

    # Bottom border
    Move-TuiCursor -Row ($Y + $Height - 1) -Col $X
    Write-Host "$($Script:TUI_BOX_BL)$hLine$($Script:TUI_BOX_BR)" -NoNewline
}

# ---------------------------------------------------------------------------
# Section 8: Key Name Constants
# ---------------------------------------------------------------------------

$Script:TUI_KEY_UP      = "up"
$Script:TUI_KEY_DOWN    = "down"
$Script:TUI_KEY_LEFT    = "left"
$Script:TUI_KEY_RIGHT   = "right"
$Script:TUI_KEY_ENTER   = "enter"
$Script:TUI_KEY_ESC     = "esc"
$Script:TUI_KEY_PGUP    = "pgup"
$Script:TUI_KEY_PGDN    = "pgdn"
$Script:TUI_KEY_HOME    = "home"
$Script:TUI_KEY_END     = "end"
$Script:TUI_KEY_SPACE   = "space"
$Script:TUI_KEY_TAB     = "tab"
$Script:TUI_KEY_BACKSPACE = "backspace"
$Script:TUI_KEY_CTRL_D  = "ctrl_d"
$Script:TUI_KEY_DELETE  = "delete"
$Script:TUI_KEY_ASTERISK = "asterisk"
$Script:TUI_KEY_MINUS   = "minus"
$Script:TUI_KEY_Q       = "q"
$Script:TUI_KEY_HELP    = "help"
$Script:TUI_KEY_NUMBER  = "number"
$Script:TUI_KEY_UNKNOWN = "unknown"

# Configurable escape sequence timeout (matching TUI_KEY_TIMEOUT in tui.sh)
$Script:TUI_KEY_TIMEOUT = 100  # milliseconds

# ---------------------------------------------------------------------------
# Section 9: Key Reading Function (D-09)
# ---------------------------------------------------------------------------

function Read-TuiKey {
    <#
    .SYNOPSIS
    Read a single keypress using [Console]::ReadKey() and decode to symbolic name.
    Sets $Script:_tui_rk_result and $Script:_tui_rk_digit.
    Caller reads these script-scope variables — do NOT wrap in $().

    Per D-09: uses [Console]::ReadKey() — PowerShell's native single-keypress API.
    [Console]::ReadKey() already decodes escape sequences, so arrow keys,
    PgUp/PgDn, Home/End all map to ConsoleKey enum values.
    No manual escape sequence parsing needed (unlike POSIX tui.sh).
    #>
    $Script:_tui_rk_result = $Script:TUI_KEY_UNKNOWN
    $Script:_tui_rk_digit = ''

    $keyInfo = $null
    try {
        $keyInfo = [Console]::ReadKey($true)
    } catch {
        # On error (e.g., input redirected), return unknown
        $Script:_tui_rk_result = $Script:TUI_KEY_UNKNOWN
        return
    }

    $char = $keyInfo.KeyChar
    $key  = $keyInfo.Key
    $modifiers = $keyInfo.Modifiers

    # --- Character-based mappings (matching tui.sh lines 205-248) ---

    # Check KeyChar first for printable characters
    switch -Regex ($char.ToString()) {
        "`r" { $Script:_tui_rk_result = $Script:TUI_KEY_ENTER; return }
        "`n" { $Script:_tui_rk_result = $Script:TUI_KEY_ENTER; return }
        ' '  { $Script:_tui_rk_result = $Script:TUI_KEY_SPACE; return }
        '\*' { $Script:_tui_rk_result = $Script:TUI_KEY_ASTERISK; return }
        '-'  { $Script:_tui_rk_result = $Script:TUI_KEY_MINUS; return }
        "`t" { $Script:_tui_rk_result = $Script:TUI_KEY_TAB; return }
        '[qQ]' {
            $Script:_tui_rk_result = $Script:TUI_KEY_Q; return
        }
        '\?' {
            $Script:_tui_rk_result = $Script:TUI_KEY_HELP; return
        }
        # Vi keys: j=down, k=up (matching standard vi convention)
        'j' {
            $Script:_tui_rk_result = $Script:TUI_KEY_DOWN; return
        }
        'k' {
            $Script:_tui_rk_result = $Script:TUI_KEY_UP; return
        }
        # Vi keys: g=Home, G=End
        'G' {
            $Script:_tui_rk_result = $Script:TUI_KEY_END; return
        }
        'g' {
            $Script:_tui_rk_result = $Script:TUI_KEY_HOME; return
        }
        '^\d$' {
            $Script:_tui_rk_digit = $char.ToString()
            $Script:_tui_rk_result = $Script:TUI_KEY_NUMBER
            return
        }
    }

    # --- ConsoleKey-based mappings (escape sequences handled natively by ReadKey) ---

    switch ($key) {
        'UpArrow'    { $Script:_tui_rk_result = $Script:TUI_KEY_UP; return }
        'DownArrow'  { $Script:_tui_rk_result = $Script:TUI_KEY_DOWN; return }
        'LeftArrow'  { $Script:_tui_rk_result = $Script:TUI_KEY_LEFT; return }
        'RightArrow' { $Script:_tui_rk_result = $Script:TUI_KEY_RIGHT; return }
        'Enter'      { $Script:_tui_rk_result = $Script:TUI_KEY_ENTER; return }
        'Escape'     { $Script:_tui_rk_result = $Script:TUI_KEY_ESC; return }
        'PageUp'     { $Script:_tui_rk_result = $Script:TUI_KEY_PGUP; return }
        'PageDown'   { $Script:_tui_rk_result = $Script:TUI_KEY_PGDN; return }
        'Home'       { $Script:_tui_rk_result = $Script:TUI_KEY_HOME; return }
        'End'        { $Script:_tui_rk_result = $Script:TUI_KEY_END; return }
        'Spacebar'   { $Script:_tui_rk_result = $Script:TUI_KEY_SPACE; return }
        'Tab'        { $Script:_tui_rk_result = $Script:TUI_KEY_TAB; return }
        'Backspace'  { $Script:_tui_rk_result = $Script:TUI_KEY_BACKSPACE; return }
        'Delete'     { $Script:_tui_rk_result = $Script:TUI_KEY_DELETE; return }

        # Ctrl+D handling — ReadKey exposes modifiers
        'D' {
            if ($modifiers -band [System.ConsoleModifiers]::Control) {
                $Script:_tui_rk_result = $Script:TUI_KEY_CTRL_D; return
            }
        }
    }

    # Fallback: process raw byte value for edge cases
    $byteVal = [int][char]$char
    switch ($byteVal) {
        10  { $Script:_tui_rk_result = $Script:TUI_KEY_ENTER; return }
        13  { $Script:_tui_rk_result = $Script:TUI_KEY_ENTER; return }
        27  { $Script:_tui_rk_result = $Script:TUI_KEY_ESC; return }
        127 { $Script:_tui_rk_result = $Script:TUI_KEY_BACKSPACE; return }
        8   { $Script:_tui_rk_result = $Script:TUI_KEY_BACKSPACE; return }
        9   { $Script:_tui_rk_result = $Script:TUI_KEY_TAB; return }
        32  { $Script:_tui_rk_result = $Script:TUI_KEY_SPACE; return }
    }

    $Script:_tui_rk_result = $Script:TUI_KEY_UNKNOWN
}

# ---------------------------------------------------------------------------
# Section 10: Character Reader for Text Input Widgets
# ---------------------------------------------------------------------------

function Read-TuiChar {
    <#
    .SYNOPSIS
    Read a single character and return its actual value (not symbolic).
    Sets $Script:_tui_rc_char to the character.
    Used by text input widgets that need the actual character value.
    Caller reads $Script:_tui_rc_char directly.
    #>
    try {
        $keyInfo = [Console]::ReadKey($true)
        $Script:_tui_rc_char = $keyInfo.KeyChar
    } catch {
        $Script:_tui_rc_char = [char]0
    }
}
