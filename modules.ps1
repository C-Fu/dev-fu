# ============================================================
# modules.ps1 — Module Pipeline Library (port of modules.sh)
#
# Module fetch engine, metadata parser, parameter collection,
# execution via WSL/bash, and result display.
#
# Port of the POSIX modules.sh to idiomatic PowerShell.
# Supports PowerShell 5.1 and PowerShell 7.
#
# Usage:
#   . .\tui.ps1
#   . .\modules.ps1
#   $result = Invoke-FluModuleExecute -ActionId "install_python"
#   Write-FluModuleResult -Result $result
# ============================================================

# ---------------------------------------------------------------------------
# Section 1: Guard — tui.ps1 must be dot-sourced first
# ---------------------------------------------------------------------------

if (-not (Test-Path variable:Script:TUI_RESET)) {
    Write-Error "tui.ps1 must be dot-sourced before modules.ps1"
    return
}

# ---------------------------------------------------------------------------
# Section 2: Module Initialization — Base URL
# ---------------------------------------------------------------------------

# Module base URL (overridable per D-06)
$Script:FLU_MODULES_BASE_URL = if ($env:FLU_MODULES_BASE_URL) {
    $env:FLU_MODULES_BASE_URL
} else {
    "https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/"
}

# ---------------------------------------------------------------------------
# Section 3: URL Resolution
# ---------------------------------------------------------------------------

function Resolve-FluModuleUrl {
    <#
    .SYNOPSIS
    Resolve action ID to GitHub raw URL.
    PowerShell port of flu_module_resolve_url().

    .PARAMETER ActionId
    Action identifier from menu.db (e.g., "install_python").

    .DESCRIPTION
    Returns full URL: https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/<actionId>.sh
    #>
    param([string]$ActionId)
    return "$($Script:FLU_MODULES_BASE_URL)$ActionId.sh"
}

# ---------------------------------------------------------------------------
# Section 4: Module Fetch (Invoke-FluModuleFetch)
# ---------------------------------------------------------------------------

function Invoke-FluModuleFetch {
    <#
    .SYNOPSIS
    Fetch a module script from GitHub with retry logic.
    PowerShell port of flu_module_fetch().

    .PARAMETER ActionId
    Action identifier (e.g., "install_python").

    .DESCRIPTION
    Uses Invoke-WebRequest (per D-07) with 3 retries and 2-second delay.
    Returns module script content as string on success.
    Returns $null and writes errors to error stream on failure.

    Matching flu_module_fetch() behaviors:
      - 3 retry attempts with 2-second delay between retries
      - Timeout: 10 seconds per attempt (matching curl --connect-timeout 10)
      - Actionable error messages including hints for network issues
    #>
    param([string]$ActionId)

    $url = Resolve-FluModuleUrl -ActionId $ActionId
    $maxAttempts = 3
    $delaySeconds = 2

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            return $response.Content
        } catch {
            $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            $errorMsg = $_.Exception.Message

            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds $delaySeconds
            } else {
                # All retries exhausted — report error with actionable hints
                Write-Error "[ERROR] Failed to fetch module: $url (status: $statusCode)"

                switch ($statusCode) {
                    404 {
                        Write-Warning "[HINT] Module not found — might be renamed or not yet published"
                    }
                    0 {
                        Write-Warning "[HINT] Check internet connection — unable to reach GitHub"
                    }
                    default {
                        Write-Warning "[HINT] Network error (HTTP $statusCode) — check internet connection or GitHub availability"
                    }
                }

                if ($errorMsg -match 'timeout|timed out') {
                    Write-Warning "[HINT] Request timed out — check your network speed or try again later"
                }

                return $null
            }
        }
    }

    return $null
}

# ---------------------------------------------------------------------------
# Section 5: Metadata Parser (ConvertFrom-FluModuleMetadata)
# ---------------------------------------------------------------------------

function ConvertFrom-FluModuleMetadata {
    <#
    .SYNOPSIS
    Parse module comment header metadata.
    PowerShell port of flu_module_parse_metadata().

    .PARAMETER ScriptContent
    Full script content string to parse.

    .DESCRIPTION
    Extracts @key: value fields from comment header block.
    Header terminates at first blank line or non-comment line.

    Returns a PSObject with properties:
      Name, Params, Platforms, Version, Deps, Timeout

    Returns $null if required fields are missing or platform check fails.

    Matching flu_module_parse_metadata() behaviors:
      - Required fields: @name, @platforms, @version
      - Defaults: @timeout=300, @params='', @deps=''
      - Platform validation against FLU_OS
    #>
    param([string]$ScriptContent)

    $lines = $ScriptContent -split "`n"

    $name = ''
    $params = ''
    $platforms = ''
    $version = ''
    $deps = ''
    $timeout = ''

    # Parse comment header — stop at first non-comment, non-blank line
    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Stop at first blank line or non-comment line
        if ([string]::IsNullOrEmpty($trimmed)) { break }
        if ($trimmed -notmatch '^#') { break }

        # Extract @key: value pairs
        if ($trimmed -match '^#\s*@name:\s*(.+)') { $name = $Matches[1].Trim() }
        if ($trimmed -match '^#\s*@params:\s*(.+)') { $params = $Matches[1].Trim() }
        if ($trimmed -match '^#\s*@platforms:\s*(.+)') { $platforms = $Matches[1].Trim() }
        if ($trimmed -match '^#\s*@version:\s*(.+)') { $version = $Matches[1].Trim() }
        if ($trimmed -match '^#\s*@deps:\s*(.+)') { $deps = $Matches[1].Trim() }
        if ($trimmed -match '^#\s*@timeout:\s*(.+)') { $timeout = $Matches[1].Trim() }
    }

    # Apply defaults
    if ([string]::IsNullOrEmpty($timeout)) { $timeout = '300' }

    # Validate required fields
    if ([string]::IsNullOrEmpty($name)) {
        Write-Error "[ERROR] Module missing required @name field"
        return $null
    }
    if ([string]::IsNullOrEmpty($platforms)) {
        Write-Error "[ERROR] Module missing required @platforms field"
        return $null
    }
    if ([string]::IsNullOrEmpty($version)) {
        Write-Error "[ERROR] Module missing required @version field"
        return $null
    }

    # Platform validation — check FLU_OS against @platforms list
    $currentOs = $env:FLU_OS
    if (-not [string]::IsNullOrEmpty($currentOs)) {
        $platList = $platforms -split ',' | ForEach-Object { $_.Trim() }
        if ($currentOs -notin $platList) {
            Write-Error "[ERROR] Module not available for this platform ($currentOs)"
            return $null
        }
    }

    # Return structured object
    return [PSCustomObject]@{
        Name      = $name
        Params    = $params
        Platforms = $platforms
        Version   = $version
        Deps      = $deps
        Timeout   = $timeout
    }
}
