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
