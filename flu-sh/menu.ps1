# ============================================================
# menu.ps1 — PowerShell Menu DSL Parser (port of menu.sh)
#
# Parses pipe-delimited menu definition files and provides
# tree query functions for the navigation engine.
# Sources tui.ps1 for TUI primitives.
#
# Usage:
#   . .\tui.ps1
#   . .\menu.ps1
#   Import-FluMenu -DslFile "menu.db"
#   Get-FluMenuChildren ""                  # Level 1 items
#   Get-FluMenuChildren "Developer Tools"   # Level 2 items under Developer Tools
#   Get-FluMenuChildren "Developer Tools|Languages"  # Level 3 items
#
# Port of the POSIX menu.sh to idiomatic PowerShell.
# Supports PowerShell 5.1 and PowerShell 7.
# ============================================================

# ---------------------------------------------------------------------------
# Section 1: Guard — verify tui.ps1 was sourced
# ---------------------------------------------------------------------------

# menu.sh checks for TUI_RESET. In PowerShell, check for script-scope variables
# that tui.ps1 defines.
if (-not (Test-Path variable:Script:TUI_RESET)) {
    Write-Error "tui.ps1 must be dot-sourced before menu.ps1"
    return
}

# ---------------------------------------------------------------------------
# Section 2: Script-Scope Storage Variables
# ---------------------------------------------------------------------------

$Script:_fluMenuLines = @()       # Array of raw "L1|L2|L3|action" strings
$Script:_fluMenuL1 = @()          # Unique Level 1 labels (array of strings)
$Script:_fluMenuL2 = @()          # Unique L1|L2 pairs (array of strings)
$Script:_fluMenuL3 = @()          # Unique L1|L2|L3 triples (array of strings)
$Script:_fluMenuChildren = @()    # Cached children from last Get-FluMenuChildren call

# ---------------------------------------------------------------------------
# Section 3: DSL Parser — Import-FluMenu
# ---------------------------------------------------------------------------

function Import-FluMenu {
    <#
    .SYNOPSIS
    Parse a pipe-delimited menu DSL file into indexed storage.
    PowerShell port of flu_menu_load().

    .PARAMETER DslFile
    Path to the menu definition file (e.g., "menu.db").

    .DESCRIPTION
    Parses all non-comment, non-empty lines from the DSL file.
    Builds unique lists for Level 1, Level 2, and Level 3 labels.
    Lines format: L1|L2|L3|action

    Sets script-scope variables:
      $Script:_fluMenuLines  — array of raw "L1|L2|L3|action" strings
      $Script:_fluMenuL1     — array of unique L1 labels
      $Script:_fluMenuL2     — array of unique "L1|L2" strings
      $Script:_fluMenuL3     — array of unique "L1|L2|L3" strings
    #>
    param([string]$DslFile)

    if (-not (Test-Path $DslFile)) {
        Write-Error "Menu definition not found: $DslFile"
        return
    }

    # Read all non-comment, non-empty lines
    $allLines = Get-Content $DslFile | Where-Object {
        $_ -notmatch '^\s*(#|$)'  # skip comments and blank lines
    }

    $Script:_fluMenuLines = @($allLines)

    # Build Level 1 unique list
    $l1Set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $Script:_fluMenuLines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 1) {
            [void]$l1Set.Add($parts[0].Trim())
        }
    }
    $Script:_fluMenuL1 = @($l1Set) | Sort-Object

    # Build Level 2 unique list (L1|L2)
    $l2Set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $Script:_fluMenuLines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 2) {
            $l1l2 = "$($parts[0].Trim())|$($parts[1].Trim())"
            [void]$l2Set.Add($l1l2)
        }
    }
    $Script:_fluMenuL2 = @($l2Set) | Sort-Object

    # Build Level 3 unique list (L1|L2|L3)
    $l3Set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in $Script:_fluMenuLines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 3) {
            $l1l2l3 = "$($parts[0].Trim())|$($parts[1].Trim())|$($parts[2].Trim())"
            [void]$l3Set.Add($l1l2l3)
        }
    }
    $Script:_fluMenuL3 = @($l3Set) | Sort-Object
}

# ---------------------------------------------------------------------------
# Section 4: Child Lookup — Get-FluMenuChildren
# ---------------------------------------------------------------------------

function Get-FluMenuChildren {
    <#
    .SYNOPSIS
    Get children of a menu path.
    PowerShell port of flu_menu_get_children().

    .PARAMETER ParentPath
    Parent menu path:
      - "" (empty) returns Level 1 labels
      - "Developer Tools" returns L2 labels under that L1
      - "Developer Tools|Languages" returns L3 labels under that L1+L2

    .DESCRIPTION
    Returns array of child label strings.
    Also sets $Script:_fluMenuChildren array for programmatic access.
    #>
    param([string]$ParentPath)

    $children = @()

    if ([string]::IsNullOrEmpty($ParentPath)) {
        # Level 1: return all unique L1 labels
        $children = $Script:_fluMenuL1
    } else {
        $depth = ($ParentPath -split '\|').Count
        if ($depth -eq 1) {
            # Parent is L1, return L2 labels
            foreach ($l2 in $Script:_fluMenuL2) {
                $parts = $l2 -split '\|'
                if ($parts[0].Trim() -eq $ParentPath) {
                    $children += $parts[1].Trim()
                }
            }
            $children = $children | Select-Object -Unique | Sort-Object
        } elseif ($depth -eq 2) {
            # Parent is L1|L2, return L3 labels
            foreach ($l3 in $Script:_fluMenuL3) {
                $parts = $l3 -split '\|'
                $prefix = "$($parts[0].Trim())|$($parts[1].Trim())"
                if ($prefix -eq $ParentPath) {
                    $children += $parts[2].Trim()
                }
            }
            $children = $children | Select-Object -Unique | Sort-Object
        }
    }

    $Script:_fluMenuChildren = $children
    return $children
}

# ---------------------------------------------------------------------------
# Section 5: Leaf Detection — Test-FluMenuIsLeaf
# ---------------------------------------------------------------------------

function Test-FluMenuIsLeaf {
    <#
    .SYNOPSIS
    Check if a menu path is a leaf node (has an action, not intermediate).
    PowerShell port of flu_menu_is_leaf().

    .PARAMETER Path
    Menu path like "Developer Tools|Languages|Python".

    .DESCRIPTION
    Returns $true if path is a leaf (has action field in menu.db).
    Returns $false if path has children (is intermediate).
    #>
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return $false
    }

    # If path has 3 levels, it's always a leaf (max depth reached per MENU-01)
    $depth = ($Path -split '\|').Count
    if ($depth -ge 3) {
        return $true
    }

    # If path has children at next level, it's NOT a leaf
    $children = Get-FluMenuChildren -ParentPath $Path
    if ($children.Count -gt 0) {
        return $false
    }

    # If path matches an action in menu lines (unusual case), it's a leaf
    foreach ($line in $Script:_fluMenuLines) {
        $parts = $line -split '\|'
        $linePath = ''
        if ($depth -eq 1 -and $parts.Count -ge 2) {
            $linePath = $parts[0].Trim()
        } elseif ($depth -eq 2 -and $parts.Count -ge 3) {
            $linePath = "$($parts[0].Trim())|$($parts[1].Trim())"
        }
        if ($linePath -eq $Path -and $parts[-1].Trim() -ne '') {
            return $true
        }
    }

    return $false
}

# ---------------------------------------------------------------------------
# Section 6: Breadcrumb — Get-FluMenuBreadcrumb
# ---------------------------------------------------------------------------

function Get-FluMenuBreadcrumb {
    <#
    .SYNOPSIS
    Convert menu path to breadcrumb string.
    PowerShell port of flu_menu_get_breadcrumb().

    .PARAMETER Path
    Pipe-delimited menu path.

    .DESCRIPTION
    Returns "Main Menu > Developer Tools > Languages > Python".
    #>
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return "Main Menu"
    }
    $parts = $Path -split '\|'
    return "Main Menu > $($parts -join ' > ')"
}

# ---------------------------------------------------------------------------
# Section 7: Action Lookup — Get-FluMenuAction
# ---------------------------------------------------------------------------

function Get-FluMenuAction {
    <#
    .SYNOPSIS
    Extract action ID for a full L1|L2|L3 menu path.
    PowerShell port of flu_menu_get_action().

    .PARAMETER Path
    Pipe-delimited menu path (e.g., "Developer Tools|Languages|Python").

    .DESCRIPTION
    Returns the action field (4th pipe-delimited field) from menu.db.
    Returns empty string if not found.
    #>
    param([string]$Path)

    foreach ($line in $Script:_fluMenuLines) {
        $parts = $line -split '\|'
        if ($parts.Count -ge 4) {
            $l1l2l3 = "$($parts[0].Trim())|$($parts[1].Trim())|$($parts[2].Trim())"
            if ($l1l2l3 -eq $Path) {
                return $parts[3].Trim()
            }
        }
    }
    return ''
}

# ---------------------------------------------------------------------------
# Section 8: Menu Navigation Engine — Show-FluMenuNavigate
# ---------------------------------------------------------------------------

function Show-FluMenuNavigate {
    <#
    .SYNOPSIS
    Hierarchical menu navigation engine with up to 3 levels.
    PowerShell port of flu_menu_navigate().

    .PARAMETER DslFile
    Path to the menu definition file (menu.db).

    .DESCRIPTION
    Interactive menu navigation using Show-TuiSelect for each level.
    Maintains a path stack for back-navigation.
    Left arrow / Esc go back to parent menu.
    Leaf selection returns the full path.

    Sets $Script:TUI_RESULT to the full menu path on leaf selection.
    (e.g., "Developer Tools|Languages|Python")
    Sets $Script:TUI_RESULT to $null on cancel at root.

    Returns 0 on leaf selection, 1 on cancel at root.

    Matching flu_menu_navigate() behaviors:
      - 3-level depth limit
      - Breadcrumb displayed as subtitle at each level
      - Left arrow / Esc for back-navigation (except at root where Esc cancels)
      - TUI lifecycle managed internally (calls Initialize-Tui/Restore-Tui)
      - Fallback mode when no TTY available
    #>
    param([string]$DslFile)

    # Load the menu definition
    Import-FluMenu -DslFile $DslFile

    if ($Script:_fluMenuLines.Count -eq 0) {
        Write-Error "Menu definition is empty: $DslFile"
        return 1
    }

    # Fallback: non-TTY numbered prompt
    if (-not $Script:_tui_use_tui) {
        $result = Show-FluMenuNavigateFallback -DslFile $DslFile
        $Script:TUI_RESULT = $result
        return $(if ($result) { 0 } else { 1 })
    }

    Initialize-Tui
    Clear-TuiScreen

    # Path stack: array of selected labels at each level
    $pathStack = @()  # e.g., @("Developer Tools", "Languages", "Python")
    $running = $true

    while ($running) {
        # Get children for current path
        $currentPath = $pathStack -join '|'
        $children = Get-FluMenuChildren -ParentPath $currentPath

        if ($children.Count -eq 0) {
            # No children — shouldn't happen with valid menu.db
            $running = $false
            break
        }

        # Build breadcrumb for current level
        $breadcrumb = if ($pathStack.Count -gt 0) {
            Get-FluMenuBreadcrumb -Path ($pathStack -join '|')
        } else {
            "Main Menu"
        }

        # Build title based on level
        $titlePrefix = switch ($pathStack.Count) {
            0 { "flu.sh $($Script:FLU_VERSION) — Main Menu" }
            1 { "flu.sh $($Script:FLU_VERSION) — $($pathStack[0])" }
            2 { "flu.sh $($Script:FLU_VERSION) — $($pathStack[0]) > $($pathStack[1])" }
            default { "flu.sh $($Script:FLU_VERSION)" }
        }

        # Render the menu level using Show-TuiSelect
        Show-TuiSelect -Title $titlePrefix -Subtitle $breadcrumb -Items $children
        $selectedIndex = $Script:TUI_RESULT

        if ($selectedIndex -lt 0) {
            # Esc/q/Left pressed — go back or exit
            if ($pathStack.Count -eq 0) {
                # At root level, Esc cancels entirely
                $Script:TUI_RESULT = $null
                $running = $false
                break
            } else {
                # Go back to parent level (pop last segment)
                $pathStack = $pathStack[0..($pathStack.Count - 2)]
                continue
            }
        }

        # Get the selected label
        $currentLabel = $children[$selectedIndex]
        $pathStack += $currentLabel

        # Check if this is a leaf or intermediate node
        $fullPath = $pathStack -join '|'

        if (Test-FluMenuIsLeaf -Path $fullPath) {
            # Leaf node selected — return the full path
            $Script:TUI_RESULT = $fullPath
            $running = $false
            break
        }

        # Intermediate node — will loop to show children on next iteration
        if ($pathStack.Count -ge 3) {
            # Max depth reached (3 levels) — treat as leaf
            $Script:TUI_RESULT = $fullPath
            $running = $false
            break
        }
    }

    Restore-Tui

    if ($Script:TUI_RESULT) { return 0 } else { return 1 }
}

# ---------------------------------------------------------------------------
# Section 9: Navigation Fallback — Show-FluMenuNavigateFallback
# ---------------------------------------------------------------------------

function Show-FluMenuNavigateFallback {
    <#
    .SYNOPSIS
    Numbered text prompt fallback for menu navigation (no TTY).
    PowerShell port of _flu_menu_navigate_fallback().

    .PARAMETER DslFile
    Path to the menu definition file (menu.db).

    .DESCRIPTION
    Provides the same 3-level hierarchical navigation using numbered
    text prompts when TERM=dumb or no TTY is available.
    Called automatically by Show-FluMenuNavigate when $_tui_use_tui is $false.

    Returns the full pipe-delimited path on selection, or $null on cancel.
    #>
    param([string]$DslFile)

    Import-FluMenu -DslFile $DslFile

    $pathStack = @()
    $running = $true

    while ($running) {
        $currentPath = $pathStack -join '|'
        $children = Get-FluMenuChildren -ParentPath $currentPath

        if ($children.Count -eq 0) {
            Write-Host "No menu items available."
            return $null
        }

        $breadcrumb = Get-FluMenuBreadcrumb -Path ($pathStack -join '|')
        Write-Host ""
        Write-Host $breadcrumb
        Write-Host "─────────────────────"

        for ($i = 0; $i -lt $children.Count; $i++) {
            $num = $i + 1
            Write-Host ("  {0}) {1}" -f $num, $children[$i])
        }
        if ($pathStack.Count -gt 0) {
            Write-Host "  0) ← Back"
        } else {
            Write-Host "  0) Exit"
        }

        $choice = Read-Host "Enter number"
        $num = 0
        if (-not [int]::TryParse($choice, [ref]$num)) {
            Write-Host "Invalid input."
            continue
        }

        if ($num -eq 0) {
            if ($pathStack.Count -gt 0) {
                # Go back to parent level
                $pathStack = $pathStack[0..($pathStack.Count - 2)]
            } else {
                # Exit at root
                return $null
            }
            continue
        }

        if ($num -ge 1 -and $num -le $children.Count) {
            $selectedLabel = $children[$num - 1]
            $pathStack += $selectedLabel
            $fullPath = $pathStack -join '|'

            if (Test-FluMenuIsLeaf -Path $fullPath -or $pathStack.Count -ge 3) {
                return $fullPath
            }
            # Otherwise, loop to show children at next level
        }
    }

    return $null
}
