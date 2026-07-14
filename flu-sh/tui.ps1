# ============================================================
# tui.ps1 -- PowerShell TUI Engine Foundation
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
        # VT processing not available -- ASCII fallback mode
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
$Script:TUI_MAGENTA = "$ESC[35m"
$Script:TUI_WHITE = "$ESC[37m"

# ---------------------------------------------------------------------------
# Section 2.5: Color Theme Support (D-17, D-18)
# ---------------------------------------------------------------------------

function Apply-FluTheme {
    <#
    .SYNOPSIS
    Apply FLU_THEME to ANSI color variables.
    Themes: dark (default), light, monochrome.

    .DESCRIPTION
    Reads $env:FLU_THEME and remaps ANSI color palette.
    Called at startup after Get-FluPlatform.
    Theme persists for the lifetime of the script.
    #>
    $theme = $env:FLU_THEME
    if ([string]::IsNullOrEmpty($theme)) { $theme = 'dark' }

    switch ($theme.ToLower()) {
        'light' {
            # Light theme: bright background colors (higher ANSI codes)
            $Script:TUI_RED     = "$ESC[91m"   # Bright red
            $Script:TUI_GREEN   = "$ESC[92m"   # Bright green
            $Script:TUI_YELLOW  = "$ESC[93m"   # Bright yellow
            $Script:TUI_CYAN    = "$ESC[96m"   # Bright cyan
            $Script:TUI_MAGENTA = "$ESC[95m"   # Bright magenta
            $Script:TUI_WHITE   = "$ESC[97m"   # Bright white
            # Bold, dim, rev stay the same
        }
        'monochrome' {
            # Monochrome: no colors at all
            $Script:TUI_RED     = "$ESC[0m"
            $Script:TUI_GREEN   = "$ESC[0m"
            $Script:TUI_YELLOW  = "$ESC[0m"
            $Script:TUI_CYAN    = "$ESC[0m"
            $Script:TUI_MAGENTA = "$ESC[0m"
            $Script:TUI_WHITE   = "$ESC[0m"
            # Bold, dim, rev also reset
            $Script:TUI_BOLD    = "$ESC[0m"
            $Script:TUI_DIM     = "$ESC[0m"
            $Script:TUI_REV     = "$ESC[0m"
        }
        'dark' {
            # Dark theme: standard ANSI colors (default -- no change needed)
        }
        default {
            # Unknown theme: fall back to dark (no change)
        }
    }
}

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
    $Script:TUI_BOX_TL = '+'; $Script:TUI_BOX_TR = '+'
    $Script:TUI_BOX_BL = '+'; $Script:TUI_BOX_BR = '+'
    $Script:TUI_BOX_H  = '-'; $Script:TUI_BOX_V  = '|'
} else {
    $Script:TUI_BOX_TL = '+'; $Script:TUI_BOX_TR = '+'
    $Script:TUI_BOX_BL = '+'; $Script:TUI_BOX_BR = '+'
    $Script:TUI_BOX_H  = '-'; $Script:TUI_BOX_V  = '|'
}

# ---------------------------------------------------------------------------
# Section 4: TTY / Terminal Availability Check
# ---------------------------------------------------------------------------

# _tui_use_tui equivalent -- detect if TUI mode is possible
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
    Initialize terminal for TUI mode -- hide cursor, enable raw key input.
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
    Restore terminal to normal state -- show cursor, clear screen, restore key mode.
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
    Caller reads these script-scope variables -- do NOT wrap in $().

    Per D-09: uses [Console]::ReadKey() -- PowerShell's native single-keypress API.
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

        # Ctrl+D handling -- ReadKey exposes modifiers
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

# ---------------------------------------------------------------------------
# Section 11: Single-Select Menu Widget (Show-TuiSelect)
# ---------------------------------------------------------------------------

function Show-TuiSelect {
    <#
    .SYNOPSIS
    Single-select TUI menu widget. PowerShell port of tui_sh tui_select().

    .PARAMETER Title
    Box title displayed in the top border.

    .PARAMETER Subtitle
    Context line displayed below title (e.g., breadcrumb).

    .PARAMETER Items
    Array of item strings to display and choose from.

    .DESCRIPTION
    Renders a full-screen bordered box with items, keyboard navigation,
    scroll indicators, help footer, and number jump.
    Sets $Script:TUI_RESULT to 0-based selected index on Enter.
    Sets $Script:TUI_RESULT to -1 on Esc/q cancel.
    Falls back to numbered text prompt when $_tui_use_tui is $false.

    Matching tui.sh tui_select() behaviors:
      - Items overflow -> scroll with ^more / vmore indicators
      - PgUp/PgDn jump by page height
      - Home/End jump to first/last
      - Number accumulator: typing 1,2,3 -> jumps to item index as digits accumulate
      - Help footer with keyboard legend
      - Reverse video highlight on current item ($Script:TUI_REV)
    #>
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Items
    )

    # Handle empty items list
    if ($Items.Count -eq 0) {
        $Script:TUI_RESULT = -1
        return
    }

    # Fallback mode: numbered text prompt
    if (-not $Script:_tui_use_tui) {
        $result = Show-TuiSelectFallback -Title $Title -Subtitle $Subtitle -Items $Items
        $Script:TUI_RESULT = $result
        return
    }

    Initialize-Tui
    Clear-TuiScreen

    $itemCount   = $Items.Count
    $currentIndex = 0
    $topIndex     = 0      # first visible item index (0-based, matching $Items array)
    $digitAccum   = ''     # multi-digit number accumulator
    $running      = $true
    $needsRedraw  = $true

    # Get terminal dimensions
    $termRows = 24
    $termCols = 80
    try {
        $termRows = $Host.UI.RawUI.WindowSize.Height
        $termCols = $Host.UI.RawUI.WindowSize.Width
    } catch {}

    # Calculate box dimensions
    $boxWidth = [Math]::Min(76, $termCols - 2)
    if ($boxWidth -lt 20) { $boxWidth = 20 }
    # Overhead: title row + subtitle row + separator + footer row + 2 border rows + status row = 7 rows
    $overheadRows = 7
    if (-not $Subtitle) { $overheadRows -= 1 }  # no subtitle row needed
    $visibleRows = [Math]::Max(1, $termRows - $overheadRows)

    $boxHeight = $visibleRows + $overheadRows
    if ($boxHeight -gt $termRows) {
        $boxHeight = $termRows
        $visibleRows = [Math]::Max(1, $boxHeight - $overheadRows)
    }

    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))
    $innerWidth = [Math]::Max(4, $boxWidth - 4)  # inside padding (2 each side)

    # Phase tracking for terminal resize detection
    $prevNeedsScroll = $false

    while ($running) {
        if ($needsRedraw) {
            Clear-TuiScreen

            # Render the full box inline (matching tui.sh _tui_render_select layout):
            # Row layout: top border, title row, [subtitle row], separator, items, status, bottom, footer

            $r = $boxY
            $innerW = $boxWidth - 2
            $hLine = $Script:TUI_BOX_H * $innerW
            $contentWidth = [Math]::Max(4, $boxWidth - 4)  # space for item text between V borders + padding

            # Top border
            Move-TuiCursor -Row $r -Col $boxX
            Write-Host "$($Script:TUI_BOX_TL)$hLine$($Script:TUI_BOX_TR)" -NoNewline
            $r++

            # Title row
            $plainTitle = $Title -replace '\x1b\[[0-9;]*m', ''
            $titleLen = [Math]::Min($plainTitle.Length, $innerW)
            $titleShow = $plainTitle.Substring(0, $titleLen)
            $titlePad = $innerW - $titleLen
            $titlePl = [Math]::Floor($titlePad / 2)
            $titlePr = $titlePad - $titlePl

            Move-TuiCursor -Row $r -Col $boxX
            Write-Host $Script:TUI_BOX_V -NoNewline
            Write-Host (" " * [Math]::Max(0, $titlePl)) -NoNewline
            Write-Host "$($Script:TUI_BOLD)$titleShow$($Script:TUI_RESET)" -NoNewline
            Write-Host (" " * [Math]::Max(0, $titlePr)) -NoNewline
            Write-Host $Script:TUI_BOX_V -NoNewline
            $r++

            # Subtitle row (if present)
            if ($Subtitle) {
                $plainSub = $Subtitle -replace '\x1b\[[0-9;]*m', ''
                $subLen = [Math]::Min($plainSub.Length, $innerW)
                $subShow = $plainSub.Substring(0, $subLen)
                $subPad = $innerW - $subLen
                $subPl = [Math]::Floor($subPad / 2)
                $subPr = $subPad - $subPl

                Move-TuiCursor -Row $r -Col $boxX
                Write-Host $Script:TUI_BOX_V -NoNewline
                Write-Host (" " * [Math]::Max(0, $subPl)) -NoNewline
                Write-Host "$($Script:TUI_DIM)$subShow$($Script:TUI_RESET)" -NoNewline
                Write-Host (" " * [Math]::Max(0, $subPr)) -NoNewline
                Write-Host $Script:TUI_BOX_V -NoNewline
                $r++
            }

            # Separator row
            Move-TuiCursor -Row $r -Col $boxX
            Write-Host $Script:TUI_BOX_V -NoNewline
            Write-Host $hLine -NoNewline
            Write-Host $Script:TUI_BOX_V -NoNewline
            $r++

            # Item rendering area starts here
            $itemStartRow = $r

            # Footer and bottom border positions
            $footerRow = $boxY + $boxHeight - 2
            $bottomRow = $boxY + $boxHeight - 1

            # Calculate how many rows available for items
            $availableForItems = $footerRow - $itemStartRow
            $renderedVisible = [Math]::Max(1, $availableForItems)

            # Top scroll indicator
            if ($itemCount -gt $renderedVisible -and $topIndex -gt 0) {
                Move-TuiCursor -Row $itemStartRow -Col ($boxX + 2)
                Write-Host "^ $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
                $itemStartRow++
                $renderedVisible--
            }

            $itemsToRender = [Math]::Min($renderedVisible, $itemCount - $topIndex)

            for ($i = 0; $i -lt $itemsToRender; $i++) {
                $itemIdx = $topIndex + $i
                $row = $itemStartRow + $i
                $isCurrent = ($itemIdx -eq $currentIndex)

                # Render item at position
                $itemText = $Items[$itemIdx]
                # Truncate to fit content width
                if ($itemText.Length -gt $contentWidth) {
                    $itemText = $itemText.Substring(0, $contentWidth - 3) + '...'
                }
                $padLen = [Math]::Max(0, $contentWidth - $itemText.Length)
                $paddedText = $itemText + (' ' * $padLen)

                Move-TuiCursor -Row $row -Col ($boxX + 2)
                if ($isCurrent) {
                    Write-Host "$($Script:TUI_REV)$paddedText$($Script:TUI_RESET)" -NoNewline
                } else {
                    Write-Host $paddedText -NoNewline
                }
            }

            $itemsEndRow = $itemStartRow + $itemsToRender - 1

            # Bottom scroll indicator
            if ($itemCount -gt $visibleRows -and ($topIndex + $itemsToRender) -lt $itemCount) {
                Move-TuiCursor -Row $itemsEndRow -Col ($boxX + 2)
                Write-Host "v $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
            }

            # Fill remaining body rows with empty V-bordered lines up to footer
            $fillRow = $itemStartRow + $itemsToRender
            while ($fillRow -lt $footerRow) {
                Move-TuiCursor -Row $fillRow -Col $boxX
                Write-Host $Script:TUI_BOX_V -NoNewline
                Write-Host (" " * $innerW) -NoNewline
                Write-Host $Script:TUI_BOX_V -NoNewline
                $fillRow++
            }

            # Help footer row
            $footerText = "^v jk move  [.] select  Esc/q cancel  ? help  Home End PgUp PgDn"
            $footerCol = $boxX + [Math]::Max(0, [Math]::Floor(($boxWidth - $footerText.Length) / 2))
            Move-TuiCursor -Row $footerRow -Col $footerCol
            Write-Host "$($Script:TUI_DIM)$footerText$($Script:TUI_RESET)" -NoNewline

            # Bottom border
            Move-TuiCursor -Row $bottomRow -Col $boxX
            Write-Host "$($Script:TUI_BOX_BL)$hLine$($Script:TUI_BOX_BR)" -NoNewline

            $needsRedraw = $false
        }

        # Read key
        Read-TuiKey
        $key = $Script:_tui_rk_result

        # Apply accumulated number if the key is not a digit
        if ($key -ne $Script:TUI_KEY_NUMBER -and $digitAccum -ne '') {
            if ([int]::TryParse($digitAccum, [ref]$null)) {
                $targetIdx = [int]$digitAccum
                if ($targetIdx -ge 1 -and $targetIdx -le $itemCount) {
                    $currentIndex = $targetIdx - 1  # convert 1-based to 0-based
                    if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
                    if ($currentIndex -ge $topIndex + $renderedVisible) {
                        $topIndex = [Math]::Max(0, $currentIndex - [Math]::Max(1, $renderedVisible - 1))
                    }
                    $needsRedraw = $true
                }
            }
            $digitAccum = ''
        }

        switch ($key) {
            $Script:TUI_KEY_UP {
                if ($currentIndex -gt 0) {
                    $currentIndex--
                    if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
                }
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_DOWN {
                if ($currentIndex -lt $itemCount - 1) {
                    $currentIndex++
                    if ($currentIndex -ge $topIndex + $renderedVisible) {
                        $topIndex = [Math]::Max(0, $currentIndex - $renderedVisible + 1)
                    }
                }
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_PGUP {
                $currentIndex = [Math]::Max(0, $currentIndex - [Math]::Max(1, $visibleRows))
                $topIndex = [Math]::Max(0, $topIndex - [Math]::Max(1, $visibleRows))
                if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_PGDN {
                $currentIndex = [Math]::Min($itemCount - 1, $currentIndex + [Math]::Max(1, $visibleRows))
                $topIndex = [Math]::Min(
                    [Math]::Max(0, $itemCount - [Math]::Max(1, $visibleRows)),
                    $topIndex + [Math]::Max(1, $visibleRows)
                )
                if ($topIndex -lt 0) { $topIndex = 0 }
                if ($currentIndex -ge $topIndex + $renderedVisible) {
                    $topIndex = [Math]::Max(0, $currentIndex - $renderedVisible + 1)
                }
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_HOME {
                $currentIndex = 0
                $topIndex = 0
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_END {
                $currentIndex = $itemCount - 1
                $topIndex = [Math]::Max(0, $itemCount - [Math]::Max(1, $visibleRows))
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_ENTER {
                $Script:TUI_RESULT = $currentIndex
                $running = $false
            }
            $Script:TUI_KEY_ESC {
                $Script:TUI_RESULT = -1
                $running = $false
            }
            $Script:TUI_KEY_LEFT {
                # Left arrow: exit (used by menu navigation for back-navigation)
                # Menu handles root vs non-root via pathStack.Count check
                $Script:TUI_RESULT = -1
                $running = $false
            }
            $Script:TUI_KEY_Q {
                $Script:TUI_RESULT = -1
                $running = $false
            }
            $Script:TUI_KEY_HELP {
                # Toggle help -- for now, just redraw (extended help in future plans)
                $needsRedraw = $true
                $digitAccum = ''
            }
            $Script:TUI_KEY_NUMBER {
                # Multi-digit number accumulator (matching tui.sh behavior)
                $digitAccum += $Script:_tui_rk_digit
                $needsRedraw = $true
            }
            default {
                $digitAccum = ''
            }
        }
    }

    Restore-Tui
}

function Show-TuiSelectFallback {
    <#
    .SYNOPSIS
    Numbered text prompt fallback when TUI is unavailable.
    Matches tui.sh _tui_fallback_prompt() behavior.
    #>
    param([string]$Title, [string]$Subtitle, [string[]]$Items)

    Write-Host ""
    Write-Host "  $Title"
    if ($Subtitle) { Write-Host "  $Subtitle" }
    Write-Host "  ---"

    $idx = 1
    foreach ($item in $Items) {
        Write-Host ("{0,3}) {1}" -f $idx, $item)
        $idx++
    }

    Write-Host ""
    $choice = Read-Host "Enter number (1-$($Items.Count)) or empty to cancel"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return -1
    }

    $num = 0
    if ([int]::TryParse($choice, [ref]$num)) {
        if ($num -ge 1 -and $num -le $Items.Count) {
            return $num - 1
        }
        if ($num -eq 0) {
            Write-Host "Invalid selection"
            return -1
        }
    }
    Write-Host "Invalid input: not a number"
    return -1
}

# ============================================================
# tui.ps1 -- Interactive Widgets (Plan 06-02)
#
# Multi-select checklist, radio single-select, yes/no
# confirmation, and freeform text input widgets.
# All match POSIX tui.sh widget behaviors exactly.
# ============================================================

# ---------------------------------------------------------------------------
# Section 12: Multi-Select Checklist Widget (Show-TuiChecklist)
# ---------------------------------------------------------------------------

function Show-TuiChecklist {
    <#
    .SYNOPSIS
    Multi-select checklist TUI widget. PowerShell port of tui_checklist().

    .PARAMETER Title
    Box title.
    .PARAMETER Subtitle
    Context line below title.
    .PARAMETER Items
    Array of item strings.
    .PARAMETER Checked
    Array of 0-based indices that start pre-checked (optional).

    .DESCRIPTION
    Renders items with [x]/[ ] toggle indicators. Space toggles current item.
    * (asterisk) selects all. - (minus) deselects all.
    Enter confirms selection. Esc/q cancels.

    Sets $Script:TUI_RESULT to space-separated string of selected 0-based indices.
    E.g., "0 3 5" means items at indices 0, 3, and 5 are selected.
    Sets $Script:TUI_RESULT to "" on cancel.

    Matching tui_checklist() behaviors:
      - [x] indicator for checked, [ ] for unchecked
      - Space toggles current item
      - * key selects ALL items (TUI_KEY_ASTERISK)
      - - key deselects ALL items (TUI_KEY_MINUS)
      - Reverse-video highlight on current item
      - Scroll indicators ^more/vmore
      - Help footer: "^v jk move  Space toggle  * all  - none  [.] confirm  Esc/q cancel"
    #>
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Items,
        [int[]]$Checked = @()
    )

    # Fallback mode
    if (-not $Script:_tui_use_tui) {
        $Script:TUI_RESULT = Show-TuiChecklistFallback -Title $Title -Subtitle $Subtitle -Items $Items -Checked $Checked
        return
    }

    Initialize-Tui
    Clear-TuiScreen

    $itemCount = $Items.Count
    $currentIndex = 0
    $topIndex = 0

    # Track checked state as boolean array
    $isChecked = @(New-Object bool[] $itemCount)
    foreach ($idx in $Checked) {
        if ($idx -ge 0 -and $idx -lt $itemCount) { $isChecked[$idx] = $true }
    }

    $running = $true
    $needsRedraw = $true

    # Terminal dimensions
    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    $boxWidth = [Math]::Min(76, $termCols - 2)
    if ($boxWidth -lt 30) { $boxWidth = 30 }
    $baseVisibleRows = [Math]::Max(1, $termRows - 7)
    $boxHeight = $baseVisibleRows + 6
    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))
    $innerWidth = [Math]::Max(4, $boxWidth - 6)  # account for [x] prefix

    while ($running) {
        if ($needsRedraw) {
            Clear-TuiScreen
            Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight -Title $Title

            if ($Subtitle) {
                Write-TuiAt -Row ($boxY + 2) -Col ($boxX + 2)
                Write-Host $Subtitle -NoNewline
            }

            $needsScroll = $itemCount -gt $baseVisibleRows
            $itemStartRow = $boxY + 3

            # Use a local render count to avoid mutating baseVisibleRows
            $_renderCount = $baseVisibleRows

            if ($needsScroll -and $topIndex -gt 0) {
                Write-TuiAt -Row $itemStartRow -Col ($boxX + 2)
                Write-Host "^ $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
                $itemStartRow++
                $_renderCount--
            }

            for ($i = 0; $i -lt [Math]::Min($_renderCount, $itemCount - $topIndex); $i++) {
                $itemIdx = $topIndex + $i
                $row = $itemStartRow + $i
                $isCurrent = ($itemIdx -eq $currentIndex)

                # Build checkbox indicator
                $check = if ($isChecked[$itemIdx]) { '[x]' } else { '[ ]' }
                $label = $Items[$itemIdx]

                # Truncate to fit
                $maxLabel = $innerWidth - 4  # [x] prefix
                if ($label.Length -gt $maxLabel) {
                    $label = $label.Substring(0, $maxLabel - 3) + '...'
                }
                $padded = $label + (' ' * [Math]::Max(0, $maxLabel - $label.Length))

                Write-TuiAt -Row $row -Col ($boxX + 2)
                if ($isCurrent) {
                    Write-Host "$($Script:TUI_REV)$check $padded$($Script:TUI_RESET)" -NoNewline
                } else {
                    Write-Host "$check $padded" -NoNewline
                }
            }

            if ($needsScroll -and ($topIndex + $_renderCount) -lt $itemCount) {
                $bottomRow = $itemStartRow + $i
                Write-TuiAt -Row $bottomRow -Col ($boxX + 2)
                Write-Host "v $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
            }

            # Footer
            $footerRow = $boxY + $boxHeight - 2
            $footerText = "^v jk move  Space toggle  * all  - none  [.] confirm  Esc/q cancel"
            Write-TuiAt -Row $footerRow -Col ($boxX + [Math]::Max(0, [Math]::Floor(($boxWidth - $footerText.Length) / 2)))
            Write-Host "$($Script:TUI_DIM)$footerText$($Script:TUI_RESET)" -NoNewline

            $needsRedraw = $false
        }

        Read-TuiKey
        $key = $Script:_tui_rk_result

        switch ($key) {
            $Script:TUI_KEY_UP {
                if ($currentIndex -gt 0) { $currentIndex-- }
                if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_DOWN {
                if ($currentIndex -lt $itemCount - 1) { $currentIndex++ }
                if ($currentIndex -ge $topIndex + $baseVisibleRows) { $topIndex = $currentIndex - $baseVisibleRows + 1 }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_PGUP {
                $currentIndex = [Math]::Max(0, $currentIndex - $baseVisibleRows)
                $topIndex = [Math]::Max(0, $topIndex - $baseVisibleRows)
                $needsRedraw = $true
            }
            $Script:TUI_KEY_PGDN {
                $currentIndex = [Math]::Min($itemCount - 1, $currentIndex + $baseVisibleRows)
                $topIndex = [Math]::Min($itemCount - $baseVisibleRows, $topIndex + $baseVisibleRows)
                if ($topIndex -lt 0) { $topIndex = 0 }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_HOME {
                $currentIndex = 0; $topIndex = 0; $needsRedraw = $true
            }
            $Script:TUI_KEY_END {
                $currentIndex = $itemCount - 1
                $topIndex = [Math]::Max(0, $itemCount - $baseVisibleRows)
                $needsRedraw = $true
            }
            $Script:TUI_KEY_SPACE {
                # Toggle current item
                $isChecked[$currentIndex] = -not $isChecked[$currentIndex]
                $needsRedraw = $true
            }
            $Script:TUI_KEY_ASTERISK {
                # Select All
                for ($idx = 0; $idx -lt $itemCount; $idx++) { $isChecked[$idx] = $true }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_MINUS {
                # Deselect All
                for ($idx = 0; $idx -lt $itemCount; $idx++) { $isChecked[$idx] = $false }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_ENTER {
                # Build space-separated index string
                $selected = @()
                for ($idx = 0; $idx -lt $itemCount; $idx++) {
                    if ($isChecked[$idx]) { $selected += $idx.ToString() }
                }
                $Script:TUI_RESULT = $selected -join ' '
                $running = $false
            }
            $Script:TUI_KEY_ESC {
                $Script:TUI_RESULT = ''
                $running = $false
            }
            $Script:TUI_KEY_Q {
                $Script:TUI_RESULT = ''
                $running = $false
            }
        }
    }

    Restore-Tui
}

function Show-TuiChecklistFallback {
    param([string]$Title, [string]$Subtitle, [string[]]$Items, [int[]]$Checked)
    Write-Host "$Title"
    if ($Subtitle) { Write-Host $Subtitle }
    $isChecked = @(New-Object bool[] $Items.Count)
    foreach ($idx in $Checked) { if ($idx -ge 0 -and $idx -lt $Items.Count) { $isChecked[$idx] = $true } }
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $mark = if ($isChecked[$i]) { '[x]' } else { '[ ]' }
        $num = $i + 1
        Write-Host "  $num) $mark $($Items[$i])"
    }
    $input = Read-Host "Enter numbers to toggle (space/comma-separated) or 0 to confirm"
    if ($input -eq '0') {
        $result = @()
        for ($i = 0; $i -lt $Items.Count; $i++) { if ($isChecked[$i]) { $result += $i.ToString() } }
        return ($result -join ' ')
    }
    $nums = $input -split '[ ,]+' | ForEach-Object { $n = 0; [int]::TryParse($_, [ref]$n) | Out-Null; $n }
    foreach ($n in $nums) {
        if ($n -ge 1 -and $n -le $Items.Count) { $isChecked[$n - 1] = -not $isChecked[$n - 1] }
    }
    $result = @()
    for ($i = 0; $i -lt $Items.Count; $i++) { if ($isChecked[$i]) { $result += $i.ToString() } }
    return ($result -join ' ')
}

# ---------------------------------------------------------------------------
# Section 13: Single-Select Radio Widget (Show-TuiRadio)
# ---------------------------------------------------------------------------

function Show-TuiRadio {
    <#
    .SYNOPSIS
    Single-select radio button TUI widget. PowerShell port of tui_radio().

    .PARAMETER Title
    Box title.
    .PARAMETER Subtitle
    Context line below title.
    .PARAMETER Items
    Array of option strings.
    .PARAMETER Default
    0-based index of default selection (optional).

    .DESCRIPTION
    Renders items with (*) for selected, (( )) for unselected.
    Enter confirms. Esc/q cancels.
    Sets $Script:TUI_RESULT to 0-based selected index.
    Sets $Script:TUI_RESULT to -1 on cancel.

    Matching tui_radio() behaviors:
      - (*) indicator on selected item, (( )) on others
      - Arrows/vi-keys to move selection
      - Scroll indicators and help footer
    #>
    param(
        [string]$Title,
        [string]$Subtitle,
        [string[]]$Items,
        [int]$Default = 0
    )

    if (-not $Script:_tui_use_tui) {
        $Script:TUI_RESULT = Show-TuiSelectFallback -Title $Title -Subtitle $Subtitle -Items $Items
        return
    }

    Initialize-Tui
    Clear-TuiScreen

    $itemCount = $Items.Count
    $currentIndex = [Math]::Max(0, [Math]::Min($Default, $itemCount - 1))
    $topIndex = 0
    $running = $true
    $needsRedraw = $true

    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }
    $boxWidth = [Math]::Min(76, $termCols - 2)
    if ($boxWidth -lt 30) { $boxWidth = 30 }
    $baseVisibleRows = [Math]::Max(1, $termRows - 7)
    $boxHeight = $baseVisibleRows + 6
    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))
    $innerWidth = [Math]::Max(4, $boxWidth - 6)

    while ($running) {
        if ($needsRedraw) {
            Clear-TuiScreen
            Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight -Title $Title

            if ($Subtitle) {
                Write-TuiAt -Row ($boxY + 2) -Col ($boxX + 2)
                Write-Host $Subtitle -NoNewline
            }

            $needsScroll = $itemCount -gt $baseVisibleRows
            $itemStartRow = $boxY + 3

            # Use a local render count to avoid mutating baseVisibleRows
            $_renderCount = $baseVisibleRows

            if ($needsScroll -and $topIndex -gt 0) {
                Write-TuiAt -Row $itemStartRow -Col ($boxX + 2)
                Write-Host "^ $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
                $itemStartRow++
                $_renderCount--
            }

            for ($i = 0; $i -lt [Math]::Min($_renderCount, $itemCount - $topIndex); $i++) {
                $itemIdx = $topIndex + $i
                $row = $itemStartRow + $i
                $isCurrent = ($itemIdx -eq $currentIndex)

                # Radio dot indicator: (*) for selected, (( )) for unselected
                $dot = if ($isCurrent) { '(*)' } else { '(( ))' }
                $label = $Items[$itemIdx]
                $maxLabel = $innerWidth - 4
                if ($label.Length -gt $maxLabel) {
                    $label = $label.Substring(0, $maxLabel - 3) + '...'
                }
                $padded = $label + (' ' * [Math]::Max(0, $maxLabel - $label.Length))

                Write-TuiAt -Row $row -Col ($boxX + 2)
                if ($isCurrent) {
                    Write-Host "$($Script:TUI_REV)$dot $padded$($Script:TUI_RESET)" -NoNewline
                } else {
                    Write-Host "$dot $padded" -NoNewline
                }
            }

            if ($needsScroll -and ($topIndex + $_renderCount) -lt $itemCount) {
                $bottomRow = $itemStartRow + $i
                Write-TuiAt -Row $bottomRow -Col ($boxX + 2)
                Write-Host "v $($Script:TUI_DIM)more$($Script:TUI_RESET)" -NoNewline
            }

            $footerRow = $boxY + $boxHeight - 2
            $footerText = "^v jk move  [.] confirm  Esc/q cancel"
            Write-TuiAt -Row $footerRow -Col ($boxX + [Math]::Max(0, [Math]::Floor(($boxWidth - $footerText.Length) / 2)))
            Write-Host "$($Script:TUI_DIM)$footerText$($Script:TUI_RESET)" -NoNewline

            $needsRedraw = $false
        }

        Read-TuiKey
        $key = $Script:_tui_rk_result

        switch ($key) {
            $Script:TUI_KEY_UP {
                if ($currentIndex -gt 0) { $currentIndex-- }
                if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_DOWN {
                if ($currentIndex -lt $itemCount - 1) { $currentIndex++ }
                if ($currentIndex -ge $topIndex + $baseVisibleRows) { $topIndex = $currentIndex - $baseVisibleRows + 1 }
                $needsRedraw = $true
            }
            $Script:TUI_KEY_HOME { $currentIndex = 0; $topIndex = 0; $needsRedraw = $true }
            $Script:TUI_KEY_END {
                $currentIndex = $itemCount - 1
                $topIndex = [Math]::Max(0, $itemCount - $baseVisibleRows)
                $needsRedraw = $true
            }
            $Script:TUI_KEY_ENTER { $Script:TUI_RESULT = $currentIndex; $running = $false }
            $Script:TUI_KEY_ESC { $Script:TUI_RESULT = -1; $running = $false }
            $Script:TUI_KEY_Q { $Script:TUI_RESULT = -1; $running = $false }
        }
    }

    Restore-Tui
}

# ---------------------------------------------------------------------------
# Section 14: Yes/No Confirmation Widget (Show-TuiYesNo)
# ---------------------------------------------------------------------------

function Show-TuiYesNo {
    <#
    .SYNOPSIS
    Yes/No confirmation TUI widget. PowerShell port of tui_yesno().

    .PARAMETER Title
    Dialog box title.
    .PARAMETER Message
    Question text displayed in the box body.
    .PARAMETER Default
    "yes" or "no" -- which option is pre-highlighted.

    .DESCRIPTION
    Renders a box with the message and Yes/No options.
    Left/Right arrows or Up/Down switch between Yes and No.
    Enter confirms. Esc cancels.
    Sets $Script:TUI_RESULT to "yes" or "no" on confirm.
    Sets $Script:TUI_RESULT to "" on cancel.

    Matching tui_yesno() behaviors:
      - Box with message text in body
      - Yes/No rendered as selectable options
      - Enter confirms, Esc cancels
      - Default pre-selects highlight
    #>
    param(
        [string]$Title,
        [string]$Message,
        [string]$Default = "no"
    )

    if (-not $Script:_tui_use_tui) {
        Write-Host "$Title"
        Write-Host $Message
        $choice = Read-Host "Enter y/yes or n/no"
        if ($choice -match '^y') {
            $Script:TUI_RESULT = 'yes'
        } else {
            $Script:TUI_RESULT = 'no'
        }
        return
    }

    Initialize-Tui
    Clear-TuiScreen

    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }

    $boxWidth = [Math]::Min(60, $termCols - 4)
    if ($boxWidth -lt 20) { $boxWidth = 20 }
    $boxHeight = 8  # title + padding + message + options + footer + borders
    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))

    # Word-wrap message to fit box inner width
    $innerWidth = $boxWidth - 4
    $wrapped = @()
    $words = $Message -split ' '
    $currentLine = ''
    foreach ($word in $words) {
        if (($currentLine.Length + $word.Length + 1) -le $innerWidth) {
            $currentLine = if ($currentLine) { "$currentLine $word" } else { $word }
        } else {
            if ($currentLine) { $wrapped += $currentLine }
            $currentLine = $word
        }
    }
    if ($currentLine) { $wrapped += $currentLine }

    $currentOption = if ($Default -eq 'yes') { 0 } else { 1 }
    $options = @('Yes', 'No')
    $running = $true
    $needsRedraw = $true

    while ($running) {
        if ($needsRedraw) {
            Clear-TuiScreen
            Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight -Title $Title

            # Render wrapped message
            $msgRow = $boxY + 2
            foreach ($line in $wrapped[0..[Math]::Min($wrapped.Count - 1, 3)]) {
                if ($msgRow -ge $boxY + $boxHeight - 4) { break }
                Write-TuiAt -Row $msgRow -Col ($boxX + 2)
                Write-Host $line -NoNewline
                $msgRow++
            }

            # Render Yes/No options
            $optRow = $boxY + $boxHeight - 4
            for ($i = 0; $i -lt 2; $i++) {
                $label = $options[$i]
                $pad = [Math]::Max(0, [Math]::Floor(($boxWidth - 4) / 4))
                $optX = $boxX + 2 + ($i * ($pad * 2 + $label.Length))
                Write-TuiAt -Row $optRow -Col $optX
                if ($i -eq $currentOption) {
                    Write-Host "$($Script:TUI_REV)[ $label ]$($Script:TUI_RESET)" -NoNewline
                } else {
                    Write-Host "[ $label ]" -NoNewline
                }
            }

            # Footer
            $footerRow = $boxY + $boxHeight - 2
            $footerText = "<- -> move  [.] confirm  Esc/q cancel"
            Write-TuiAt -Row $footerRow -Col ($boxX + [Math]::Max(0, [Math]::Floor(($boxWidth - $footerText.Length) / 2)))
            Write-Host "$($Script:TUI_DIM)$footerText$($Script:TUI_RESET)" -NoNewline

            $needsRedraw = $false
        }

        Read-TuiKey
        $key = $Script:_tui_rk_result

        switch ($key) {
            $Script:TUI_KEY_LEFT { $currentOption = 0; $needsRedraw = $true }
            $Script:TUI_KEY_RIGHT { $currentOption = 1; $needsRedraw = $true }
            $Script:TUI_KEY_UP { $currentOption = ($currentOption + 1) % 2; $needsRedraw = $true }
            $Script:TUI_KEY_DOWN { $currentOption = ($currentOption + 1) % 2; $needsRedraw = $true }
            $Script:TUI_KEY_ENTER {
                $Script:TUI_RESULT = $options[$currentOption].ToLower()
                $running = $false
            }
            $Script:TUI_KEY_ESC { $Script:TUI_RESULT = ''; $running = $false }
            $Script:TUI_KEY_Q { $Script:TUI_RESULT = ''; $running = $false }
        }
    }

    Restore-Tui
}

# ---------------------------------------------------------------------------
# Section 15: Freeform Text Input Widget (Show-TuiTextInput)
# ---------------------------------------------------------------------------

function Show-TuiTextInput {
    <#
    .SYNOPSIS
    Freeform text input TUI widget. PowerShell port of tui_text_input().

    .PARAMETER Title
    Box title.
    .PARAMETER Prompt
    Label shown before the input field (e.g., "Enter your name").
    .PARAMETER DefaultValue
    Pre-filled text (optional).

    .DESCRIPTION
    Inline text editor with cursor movement and editing.
    Left/Right move cursor. Backspace/Delete remove characters.
    Home (Ctrl+A) jumps to start. End (Ctrl+E) jumps to end.
    Enter submits. Esc cancels.

    Sets $Script:TUI_RESULT to entered text on submit.
    Sets $Script:TUI_RESULT to "" on cancel.
    Note: Unlike other widgets, 'q' does NOT cancel -- users need to type all letters.

    Matching tui_text_input() behaviors:
      - Inline cursor with bold reverse-video position indicator
      - Left/Right arrow cursor movement within text
      - Backspace deletes before cursor, Delete deletes at cursor
      - Home/End jump to start/end of text
      - Ctrl+A/Ctrl+E also mapped to Home/End
      - Max length enforced (no overflow beyond box width)
      - Help footer: "Type text  <- -> move  Home End  Backspace Delete  [.] submit  Esc cancel"
    #>
    param(
        [string]$Title,
        [string]$Prompt,
        [string]$DefaultValue = ''
    )

    if (-not $Script:_tui_use_tui) {
        Write-Host "$Title"
        $text = Read-Host -Prompt $Prompt
        if ($text) { $Script:TUI_RESULT = $text } else { $Script:TUI_RESULT = $DefaultValue }
        return
    }

    Initialize-Tui
    Clear-TuiScreen

    # Use StringBuilder for efficient text manipulation
    $textBuilder = New-Object System.Text.StringBuilder
    if ($DefaultValue) { [void]$textBuilder.Append($DefaultValue) }
    $cursorPos = $textBuilder.Length  # position AFTER last char (0 = before first char)

    $running = $true
    $needsRedraw = $true

    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }

    $boxWidth = [Math]::Min(70, $termCols - 4)
    if ($boxWidth -lt 30) { $boxWidth = 30 }
    $boxHeight = 7
    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = [Math]::Max(0, [Math]::Floor(($termRows - $boxHeight) / 2))
    $inputMaxLen = $boxWidth - 6  # padding inside box

    while ($running) {
        if ($needsRedraw) {
            Clear-TuiScreen
            Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight -Title $Title

            # Render prompt label
            Write-TuiAt -Row ($boxY + 2) -Col ($boxX + 2)
            Write-Host "$Prompt:" -NoNewline

            # Render input field background
            $inputRow = $boxY + 3
            $bgStr = ' ' * $inputMaxLen
            Write-TuiAt -Row $inputRow -Col ($boxX + 2)
            Write-Host "$($Script:TUI_REV)$bgStr$($Script:TUI_RESET)" -NoNewline

            # Render text + cursor inside input field
            $text = $textBuilder.ToString()
            $visibleText = $text
            $scrollOffset = 0

            # If text longer than field, scroll to show cursor
            if ($text.Length -gt $inputMaxLen) {
                if ($cursorPos -ge $inputMaxLen) {
                    $scrollOffset = $cursorPos - $inputMaxLen + 1
                    if ($scrollOffset + $inputMaxLen -gt $text.Length) {
                        $scrollOffset = $text.Length - $inputMaxLen + 1
                    }
                    if ($scrollOffset -lt 0) { $scrollOffset = 0 }
                }
                $visibleText = $text.Substring($scrollOffset, [Math]::Min($inputMaxLen, $text.Length - $scrollOffset))
            }

            # Pad visible text to fill field width
            $displayText = $visibleText + (' ' * [Math]::Max(0, $inputMaxLen - $visibleText.Length))

            Write-TuiAt -Row $inputRow -Col ($boxX + 2)
            Write-Host $displayText -NoNewline

            # Render cursor as bold reverse-video character
            $cursorDisplayPos = $cursorPos - $scrollOffset
            if ($cursorDisplayPos -ge 0 -and $cursorDisplayPos -lt $inputMaxLen) {
                $cursorChar = if ($cursorDisplayPos -lt $visibleText.Length) { $visibleText[$cursorDisplayPos] } else { ' ' }
                Write-TuiAt -Row $inputRow -Col ($boxX + 2 + $cursorDisplayPos)
                Write-Host "$($Script:TUI_BOLD)$($Script:TUI_REV)$cursorChar$($Script:TUI_RESET)" -NoNewline
            }

            # Footer
            $footerRow = $boxY + $boxHeight - 2
            $footerText = "Type text  <- -> move  Home End  Backspace Delete  [.] submit  Esc cancel"
            Write-TuiAt -Row $footerRow -Col ($boxX + [Math]::Max(0, [Math]::Floor(($boxWidth - $footerText.Length) / 2)))
            Write-Host "$($Script:TUI_DIM)$footerText$($Script:TUI_RESET)" -NoNewline

            $needsRedraw = $false
        }

        # Read key directly -- we need both ConsoleKey (for navigation) and KeyChar (for text).
        # Using [Console]::ReadKey() directly instead of Read-TuiKey/Read-TuiChar to avoid
        # the double-consumption bug: Read-TuiKey eats the key, leaving nothing for Read-TuiChar.
        $keyInfo = $null
        try {
            $keyInfo = [Console]::ReadKey($true)
        } catch {
            # On error (e.g., input redirected), treat as unknown/ignore
            continue
        }

        $char = $keyInfo.KeyChar
        $consoleKey = $keyInfo.Key
        $modifiers = $keyInfo.Modifiers

        # --- Navigation and editing keys ---
        switch ($consoleKey) {
            'LeftArrow' {
                if ($cursorPos -gt 0) { $cursorPos-- }
                $needsRedraw = $true
                continue
            }
            'RightArrow' {
                if ($cursorPos -lt $textBuilder.Length) { $cursorPos++ }
                $needsRedraw = $true
                continue
            }
            'Home' {
                $cursorPos = 0
                $needsRedraw = $true
                continue
            }
            'End' {
                $cursorPos = $textBuilder.Length
                $needsRedraw = $true
                continue
            }
            'Backspace' {
                if ($cursorPos -gt 0) {
                    $textBuilder.Remove($cursorPos - 1, 1)
                    $cursorPos--
                    $needsRedraw = $true
                }
                continue
            }
            'Delete' {
                if ($cursorPos -lt $textBuilder.Length) {
                    $textBuilder.Remove($cursorPos, 1)
                    $needsRedraw = $true
                }
                continue
            }
            'Enter' {
                $Script:TUI_RESULT = $textBuilder.ToString()
                $running = $false
                continue
            }
            'Escape' {
                $Script:TUI_RESULT = ''
                $running = $false
                continue
            }
        }

        # Check for Ctrl+A (Home) and Ctrl+E (End) via modifiers
        if ($consoleKey -eq 'A' -and ($modifiers -band [System.ConsoleModifiers]::Control)) {
            $cursorPos = 0
            $needsRedraw = $true
            continue
        }
        if ($consoleKey -eq 'E' -and ($modifiers -band [System.ConsoleModifiers]::Control)) {
            $cursorPos = $textBuilder.Length
            $needsRedraw = $true
            continue
        }

        # --- Printable character insertion ---
        # Note: Unlike other widgets, Show-TuiTextInput does NOT cancel on 'q'
        # -- users need to type all letters including 'q'. Esc is the cancel key.
        $charCode = [int][char]$char
        if ($charCode -ge 32 -and $charCode -le 126 -and $textBuilder.Length -lt $inputMaxLen) {
            $textBuilder.Insert($cursorPos, $char)
            $cursorPos++
            $needsRedraw = $true
        }
    }

    Restore-Tui
}
