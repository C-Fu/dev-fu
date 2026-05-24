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

# ---------------------------------------------------------------------------
# Section 6: Parameter Parser (ConvertFrom-FluParamString)
# ---------------------------------------------------------------------------

function ConvertFrom-FluParamString {
    <#
    .SYNOPSIS
    Parse semicolon-delimited parameter declarations.
    PowerShell port of _flu_parse_params().

    .PARAMETER ParamString
    Format: "name=type:choice1,choice2;name2=type:choice1,choice2"

    .DESCRIPTION
    Returns array of PSCustomObjects with Index, Name, Type, Choices properties.
    Types: radio (with choices), text (freeform), yesno (boolean).
    Default type: text.
    #>
    param([string]$ParamString)

    if ([string]::IsNullOrEmpty($ParamString)) {
        return @()
    }

    # Validate: must contain at least one '='
    if ($ParamString -notmatch '=') {
        Write-Error "[ERROR] Invalid param format: missing '=' separator"
        return @()
    }

    $result = @()
    $declarations = $ParamString -split ';' | Where-Object { $_.Trim() -ne '' }
    $idx = 0

    foreach ($decl in $declarations) {
        $parts = $decl -split '=', 2
        $name = $parts[0].Trim()
        if ([string]::IsNullOrEmpty($name)) { continue }

        $typeSpec = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "text" }

        $type = "text"
        $choices = ""

        if ($typeSpec -match ':') {
            $typeParts = $typeSpec -split ':', 2
            $type = $typeParts[0].Trim()
            $choices = if ($typeParts.Count -gt 1) { $typeParts[1].Trim() } else { "" }
        } else {
            if ($typeSpec -ne '') { $type = $typeSpec }
        }

        if ([string]::IsNullOrEmpty($type)) { $type = "text" }

        $result += [PSCustomObject]@{
            Index   = $idx
            Name    = $name
            Type    = $type
            Choices = $choices
        }
        $idx++
    }

    return $result
}

# ---------------------------------------------------------------------------
# Section 7: Parameter Collection via TUI Widgets (Invoke-FluModuleCollectParams)
# ---------------------------------------------------------------------------

function Invoke-FluModuleCollectParams {
    <#
    .SYNOPSIS
    Collect parameter values from user via TUI widgets.
    PowerShell port of flu_module_collect_params().

    .PARAMETER ParamString
    Parameter declarations string from @params metadata.

    .DESCRIPTION
    For each parameter, dispatches to appropriate TUI widget:
      - radio  → Show-TuiRadio (choices from comma-separated list)
      - text   → Show-TuiTextInput
      - yesno  → Show-TuiYesNo

    Builds and returns argument array: @('--key', 'value', '--key2', 'value2')
    Returns $null if user cancelled at any prompt.

    Matching flu_module_collect_params() behaviors:
      - Empty param string → empty array (no collection needed)
      - Cancellation (Esc) at any prompt aborts all collection
      - Radio maps TUI_RESULT index to choice string
      - Text passes TUI_RESULT directly as value
      - YesNo passes "yes" or "no" as value
    #>
    param([string]$ParamString)

    if ([string]::IsNullOrEmpty($ParamString)) {
        return @()
    }

    $paramDefs = ConvertFrom-FluParamString -ParamString $ParamString
    if ($paramDefs.Count -eq 0) {
        return @()
    }

    $args = @()

    foreach ($param in $paramDefs) {
        $value = $null

        switch ($param.Type.ToLower()) {
            'radio' {
                $choices = $param.Choices -split ',' | ForEach-Object { $_.Trim() }
                if ($choices.Count -eq 0) { continue }

                Show-TuiRadio -Title "$($param.Name)" -Subtitle "Select $($param.Name)" -Items $choices
                $selectedIdx = $Script:TUI_RESULT

                if ($selectedIdx -lt 0) {
                    # User cancelled
                    Write-Host "$($Script:TUI_YELLOW)[CANCELLED]$($Script:TUI_RESET) Parameter collection cancelled"
                    return $null
                }
                $value = $choices[$selectedIdx]
            }
            'text' {
                Show-TuiTextInput -Title "$($param.Name)" -Prompt "Enter $($param.Name)"
                $text = $Script:TUI_RESULT

                if ([string]::IsNullOrEmpty($text)) {
                    # Esc = cancelled
                    Write-Host "$($Script:TUI_YELLOW)[CANCELLED]$($Script:TUI_RESET) Parameter collection cancelled"
                    return $null
                }
                $value = $text
            }
            'yesno' {
                Show-TuiYesNo -Title "$($param.Name)" -Message "Enable $($param.Name)?" -Default "no"
                $choice = $Script:TUI_RESULT

                if ([string]::IsNullOrEmpty($choice)) {
                    Write-Host "$($Script:TUI_YELLOW)[CANCELLED]$($Script:TUI_RESET) Parameter collection cancelled"
                    return $null
                }
                $value = $choice
            }
            default {
                # Unknown type — default to text input
                Show-TuiTextInput -Title "$($param.Name)" -Prompt "Enter $($param.Name)"
                $text = $Script:TUI_RESULT
                if ([string]::IsNullOrEmpty($text)) { return $null }
                $value = $text
            }
        }

        $args += "--$($param.Name)"
        $args += $value
    }

    return $args
}

# ---------------------------------------------------------------------------
# Section 8: Module Execution (Invoke-FluModuleExecute)
# ---------------------------------------------------------------------------

function Invoke-FluModuleExecute {
    <#
    .SYNOPSIS
    Full module execution pipeline.
    PowerShell port of flu_module_execute() (D-09 execution order).

    .PARAMETER ActionId
    Action identifier from menu.db (e.g., "install_python").

    .DESCRIPTION
    Pipeline order:
      1. Fetch module script from GitHub
      2. Parse metadata from comment header
      3. Check platform compatibility
      4. Collect parameter values from user via TUI widgets
      5. Execute module via WSL/bash (per D-06)
      6. Return result object with exit code and output

    Returns a PSCustomObject with:
      ExitCode, Stdout, Stderr, ModuleName, Success

    Module execution per D-06:
      - On Windows: executes via `wsl bash <script> <args>`
      - If WSL not available: returns error with clear message
      - Uses Start-Process for subshell execution (per D-07)
    #>
    param([string]$ActionId)

    # Verify tui.ps1 sourced
    if (-not (Test-Path variable:Script:TUI_RESET)) {
        Write-Error "tui.ps1 must be dot-sourced before calling Invoke-FluModuleExecute"
        return $null
    }

    # Step 1: Fetch module
    $scriptContent = Invoke-FluModuleFetch -ActionId $ActionId
    if (-not $scriptContent) {
        return [PSCustomObject]@{
            ExitCode   = 1
            Stdout     = ''
            Stderr     = 'Failed to fetch module script'
            ModuleName = $ActionId
            Success    = $false
        }
    }

    # Step 2: Parse metadata
    $metadata = ConvertFrom-FluModuleMetadata -ScriptContent $scriptContent
    if (-not $metadata) {
        return [PSCustomObject]@{
            ExitCode   = 1
            Stdout     = ''
            Stderr     = 'Failed to parse module metadata'
            ModuleName = $ActionId
            Success    = $false
        }
    }

    # Step 3: Collect parameters
    $moduleArgs = Invoke-FluModuleCollectParams -ParamString $metadata.Params
    if ($null -eq $moduleArgs) {
        # User cancelled
        return [PSCustomObject]@{
            ExitCode   = 130
            Stdout     = ''
            Stderr     = 'User cancelled parameter collection'
            ModuleName = $metadata.Name
            Success    = $false
        }
    }

    # Step 4: Save script to temp file
    $tempScript = [System.IO.Path]::GetTempFileName() + '.sh'
    Set-Content -Path $tempScript -Value $scriptContent -NoNewline

    # Step 5: Execute via WSL/bash (per D-06)
    $wslAvailable = $false
    $bashAvailable = $false

    try {
        $wslCheck = Get-Command wsl.exe -ErrorAction SilentlyContinue
        if ($wslCheck) { $wslAvailable = $true }
    } catch {}
    try {
        $bashCheck = Get-Command bash.exe -ErrorAction SilentlyContinue
        if ($bashCheck) { $bashAvailable = $true }
    } catch {}

    if (-not $wslAvailable -and -not $bashAvailable) {
        # No WSL/bash — graceful message per D-06
        Remove-Item $tempScript -ErrorAction SilentlyContinue
        return [PSCustomObject]@{
            ExitCode   = 1
            Stdout     = ''
            Stderr     = "Module execution requires WSL (Windows Subsystem for Linux) or Git Bash.`n`nInstall WSL: wsl --install`nOr install Git Bash: https://git-scm.com/downloads"
            ModuleName = $metadata.Name
            Success    = $false
        }
    }

    # Build execution command
    $shPath = $tempScript -replace '\\', '/'  # WSL path conversion
    $timeout = [int]$metadata.Timeout

    try {
        $arguments = @()

        if ($wslAvailable) {
            $arguments = @('bash', $shPath) + $moduleArgs
            $execName = 'wsl.exe'
        } else {
            $arguments = @($shPath) + $moduleArgs
            $execName = 'bash.exe'
        }

        $process = Start-Process -FilePath $execName -ArgumentList $arguments `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\flu_stdout.txt" `
            -RedirectStandardError "$env:TEMP\flu_stderr.txt"

        $stdout = if (Test-Path "$env:TEMP\flu_stdout.txt") {
            Get-Content "$env:TEMP\flu_stdout.txt" -Raw
        } else { '' }
        $stderr = if (Test-Path "$env:TEMP\flu_stderr.txt") {
            Get-Content "$env:TEMP\flu_stderr.txt" -Raw
        } else { '' }

        Remove-Item "$env:TEMP\flu_stdout.txt", "$env:TEMP\flu_stderr.txt" -ErrorAction SilentlyContinue

        $exitCode = $process.ExitCode

    } catch {
        $exitCode = 1
        $stdout = ''
        $stderr = "Module execution error: $($_.Exception.Message)"
    }

    # Cleanup temp script
    Remove-Item $tempScript -ErrorAction SilentlyContinue

    return [PSCustomObject]@{
        ExitCode   = $exitCode
        Stdout     = $stdout
        Stderr     = $stderr
        ModuleName = $metadata.Name
        Success    = ($exitCode -eq 0)
    }
}
