# ============================================================
# modules.ps1 -- Module Pipeline Library (port of modules.sh)
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
# Section 1: Guard -- tui.ps1 must be dot-sourced first
# ---------------------------------------------------------------------------

if (-not (Test-Path variable:Script:TUI_RESET)) {
    Write-Error "tui.ps1 must be dot-sourced before modules.ps1"
    return
}

# ---------------------------------------------------------------------------
# Section 2: Module Initialization -- Base URL
# ---------------------------------------------------------------------------

# Module base URL (overridable per D-06)
$Script:FLU_MODULES_BASE_URL = if ($env:FLU_MODULES_BASE_URL) {
    $env:FLU_MODULES_BASE_URL
} else {
    "https://raw.githubusercontent.com/C-Fu/flu-modules/main/modules/"
}

# Cache and checksum configuration (per D-08, D-11)
$Script:FLU_CACHE_DIR = if ($env:FLU_CACHE_DIR) {
    $env:FLU_CACHE_DIR
} else {
    "$env:LOCALAPPDATA\flu-sh\cache"
}
$Script:FLU_CACHE_TTL = [TimeSpan]::FromHours(6)

# ---------------------------------------------------------------------------
# Section 3: URL Resolution
# ---------------------------------------------------------------------------

function Resolve-FluModuleUrl {
    <#
    .SYNOPSIS
    Resolve action ID to GitHub raw URL with platform-appropriate extension.

    .PARAMETER ActionId
    Action identifier from menu.db (e.g., "install_python").

    .PARAMETER Extension
    Optional override: 'ps1' or 'sh'. Auto-detects from platform if omitted.

    .DESCRIPTION
    .ps1 modules live in dev-fu repo (flu-sh/modules-ps/).
    .sh modules live in flu-modules repo (modules/).
    #>
    param([string]$ActionId, [string]$Extension = '')
    if ($Extension) {
        $ext = $Extension
    } elseif ($Script:FluIsWindows) {
        $ext = 'ps1'
    } else {
        $ext = 'sh'
    }
    if ($ext -eq 'ps1') {
        return "https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/flu-sh/modules-ps/$ActionId.ps1"
    }
    $base = $Script:FLU_MODULES_BASE_URL.TrimEnd('/')
    return "$base/$ActionId.sh"
}

# ---------------------------------------------------------------------------
# Section 3.5: Cache Functions
# ---------------------------------------------------------------------------

function Get-FluModuleCachePath {
    <#
    .SYNOPSIS
    Resolve cache file path for an action ID.

    .PARAMETER ActionId
    Action identifier (e.g., "install_python").

    .DESCRIPTION
    Returns path under $FLU_CACHE_DIR. Slashes in ActionId are replaced
    with underscores for safe filenames.
    #>
    param([string]$ActionId)
    $safeId = $ActionId -replace '[/\\]', '_'
    return Join-Path $Script:FLU_CACHE_DIR "$safeId.ps1"
}

function Test-FluModuleCache {
    <#
    .SYNOPSIS
    Check if a valid (non-expired) cache entry exists.

    .PARAMETER ActionId
    Action identifier.

    .DESCRIPTION
    Returns $true if cache file exists, is non-empty, and is within TTL.
    #>
    param([string]$ActionId)
    $cachePath = Get-FluModuleCachePath -ActionId $ActionId
    if (-not (Test-Path $cachePath)) { return $false }
    if (-not (Get-Item $cachePath).Length -gt 0) { return $false }
    $age = (Get-Date) - (Get-Item $cachePath).LastWriteTime
    return $age -lt $Script:FLU_CACHE_TTL
}

function Read-FluModuleCache {
    <#
    .SYNOPSIS
    Read cached module script content.

    .PARAMETER ActionId
    Action identifier.
    #>
    param([string]$ActionId)
    $cachePath = Get-FluModuleCachePath -ActionId $ActionId
    if (Test-Path $cachePath) {
        return Get-Content $cachePath -Raw
    }
    return $null
}

function Write-FluModuleCache {
    <#
    .SYNOPSIS
    Write module script content to cache atomically.

    .PARAMETER ActionId
    Action identifier.

    .PARAMETER Content
    Module script content to cache.
    #>
    param([string]$ActionId, [string]$Content)
    $cacheDir = $Script:FLU_CACHE_DIR
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $cachePath = Get-FluModuleCachePath -ActionId $ActionId
    $tmpPath = "$cacheDir\.tmp_$([System.IO.Path]::GetRandomFileName())"
    Set-Content -Path $tmpPath -Value $Content -NoNewline -Encoding utf8
    Move-Item -Path $tmpPath -Destination $cachePath -Force
}

function Invoke-FluModuleSha256 {
    <#
    .SYNOPSIS
    Compute SHA256 hash of module script content.

    .PARAMETER Content
    Script content string to hash.
    #>
    param([string]$Content)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $stream = [System.IO.MemoryStream]::new($bytes)
    $hash = (Get-FileHash -Algorithm SHA256 -InputStream $stream).Hash.ToLower()
    $stream.Dispose()
    return $hash
}

function Test-FluModuleChecksum {
    <#
    .SYNOPSIS
    Verify module script content against MANIFEST.sha256.

    .PARAMETER ActionId
    Action identifier.

    .PARAMETER Content
    Module script content to verify.

    .DESCRIPTION
    Fetches MANIFEST.sha256 from the module base URL, looks up the
    expected SHA256 hash for the action ID, and compares it against
    the computed hash of the content. Returns $true if valid, $false
    if mismatch.

    If the manifest cannot be fetched or the action ID has no entry,
    a warning is emitted and $true is returned (skip verification).
    #>
    param([string]$ActionId, [string]$Content)
    $manifestUrl = "$($Script:FLU_MODULES_BASE_URL)MANIFEST.sha256"
    try {
        $manifest = (Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -TimeoutSec 10).Content
    } catch {
        Write-Warning "[WARN] Could not fetch MANIFEST.sha256 -- skipping checksum verification"
        return $true
    }
    $expectedLine = ($manifest -split "`n") | Where-Object { $_ -match "\s$([regex]::Escape($ActionId))\.(ps1|sh)$" } | Select-Object -First 1
    if (-not $expectedLine) {
        Write-Warning "[WARN] No checksum entry for $ActionId -- skipping verification"
        return $true
    }
    $expectedHash = ($expectedLine -split '\s+')[0]
    $actualHash = Invoke-FluModuleSha256 -Content $Content
    if ($expectedHash -ne $actualHash) {
        Write-Error "[ERROR] SHA256 checksum mismatch for $ActionId"
        Write-Error "  Expected: $expectedHash"
        Write-Error "  Actual:   $actualHash"
        Write-Error "  The module script may be tampered or corrupted."
        return $false
    }
    Write-Host "  $($Script:TUI_GREEN)[verified]$($Script:TUI_RESET) SHA256 checksum OK" -NoNewline
    return $true
}

# ---------------------------------------------------------------------------
# Section 4: Module Fetch (Invoke-FluModuleFetch)
# ---------------------------------------------------------------------------

function Invoke-FluModuleFetch {
    <#
    .SYNOPSIS
    Fetch a module script from GitHub with caching, checksum verification, and retry logic.
    PowerShell port of flu_module_fetch().

    .PARAMETER ActionId
    Action identifier (e.g., "install_python").

    .DESCRIPTION
    Pipeline: cache check -> network fetch (3 retries) -> SHA256 checksum verify -> cache store -> return.
    Uses Invoke-WebRequest (per D-07) with 3 retries and 2-second delay.
    Returns module script content as string on success.
    Returns $null and writes errors to error stream on failure.

    Matching flu_module_fetch() behaviors:
      - 3 retry attempts with 2-second delay between retries
      - Timeout: 10 seconds per attempt (matching curl --connect-timeout 10)
      - Actionable error messages including hints for network issues
    #>
    param([string]$ActionId, [string]$Extension = '')

    # Ensure TLS 1.2 for GitHub (PS 5.1 defaults to Ssl3/Tls which GitHub rejects)
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

    # Step 1: Check cache first (per D-08, D-11)
    if (Test-FluModuleCache -ActionId $ActionId) {
        $cached = Read-FluModuleCache -ActionId $ActionId
        if ($cached) {
            Write-Host "  $($Script:TUI_DIM)[cached]$($Script:TUI_RESET) $ActionId" -NoNewline
            return $cached
        }
    }

    # Ensure cache directory exists for later store
    $cacheDir = $Script:FLU_CACHE_DIR
    if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }

    # Resolve URL: if Extension provided, use appropriate repo base; otherwise auto-detect
    if ($Extension) {
        if ($Extension -eq 'ps1') {
            $url = "https://raw.githubusercontent.com/C-Fu/dev-fu/refs/heads/main/flu-sh/modules-ps/$ActionId.ps1"
        } else {
            $base = $Script:FLU_MODULES_BASE_URL.TrimEnd('/')
            $url = "$base/$ActionId.$Extension"
        }
    } else {
        $url = Resolve-FluModuleUrl -ActionId $ActionId
    }
    $maxAttempts = 3
    $delaySeconds = 2

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            $content = $response.Content

            # Step 3: Verify SHA256 checksum against manifest (per T-14-01)
            if (-not (Test-FluModuleChecksum -ActionId $ActionId -Content $content)) {
                return $null
            }

            # Step 4: Store to cache
            Write-FluModuleCache -ActionId $ActionId -Content $content

            return $content
        } catch {
            $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            $errorMsg = $_.Exception.Message

            if ($attempt -lt $maxAttempts) {
                Start-Sleep -Seconds $delaySeconds
            } else {
                # All retries exhausted -- report error with actionable hints
                Write-Error "[ERROR] Failed to fetch module: $url (status: $statusCode)"

                switch ($statusCode) {
                    404 {
                        Write-Warning "[HINT] Module not found -- might be renamed or not yet published"
                    }
                    0 {
                        Write-Warning "[HINT] Check internet connection -- unable to reach GitHub"
                    }
                    default {
                        Write-Warning "[HINT] Network error (HTTP $statusCode) -- check internet connection or GitHub availability"
                    }
                }

                if ($errorMsg -match 'timeout|timed out') {
                    Write-Warning "[HINT] Request timed out -- check your network speed or try again later"
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

    # Parse comment header -- stop at first non-comment, non-blank line
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

    # Platform validation -- check FLU_OS against @platforms list
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
      - radio  -> Show-TuiRadio (choices from comma-separated list)
      - text   -> Show-TuiTextInput
      - yesno  -> Show-TuiYesNo

    Builds and returns argument array: @('--key', 'value', '--key2', 'value2')
    Returns $null if user cancelled at any prompt.

    Matching flu_module_collect_params() behaviors:
      - Empty param string -> empty array (no collection needed)
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
                # Unknown type -- default to text input
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
# Section 7.5: Execution Logging (per D-10, D-12)
# ---------------------------------------------------------------------------

function Get-FluLogPath {
    <#
    .SYNOPSIS
    Resolve execution log file path.
    PowerShell port of _flu_log_execution log file resolution.

    .DESCRIPTION
    Returns path: %APPDATA%\flu-sh\execution.log (per D-10).
    #>
    $logDir = "$env:APPDATA\flu-sh"
    return Join-Path $logDir "execution.log"
}

function ConvertFrom-FluActionOperation {
    <#
    .SYNOPSIS
    Classify action type from action_id prefix.
    PowerShell port of _flu_classify_operation().

    .PARAMETER ActionId
    Action identifier (e.g., "install_python").

    .DESCRIPTION
    Returns operation type string based on action ID prefix.
    Matches the POSIX _flu_classify_operation() classification.
    #>
    param([string]$ActionId)
    if ($ActionId -match '^install_') { return 'install' }
    if ($ActionId -match '^remove_') { return 'remove' }
    if ($ActionId -match '^create_') { return 'create' }
    if ($ActionId -match '^configure_') { return 'configure' }
    if ($ActionId -match '^set_') { return 'set' }
    if ($ActionId -match '^status_') { return 'status' }
    if ($ActionId -match '^upgrade_') { return 'upgrade' }
    return 'other'
}

function Write-FluExecutionLog {
    <#
    .SYNOPSIS
    Append execution record to TSV log file.
    PowerShell port of _flu_log_execution().

    .PARAMETER ActionId
    Action identifier executed.

    .PARAMETER Operation
    Classified operation type (install, remove, etc.).

    .PARAMETER Result
    Execution result: 'success' or 'fail'.

    .PARAMETER Version
    Module version string. Empty string becomes '-'.

    .PARAMETER DurationSeconds
    Execution duration in seconds. 0 with success becomes '-'.

    .DESCRIPTION
    Writes TSV row to %APPDATA%\flu-sh\execution.log with columns:
    timestamp, action_id, operation, result, version, duration_seconds.
    Creates header row if file does not exist (per D-12 format).
    #>
    param(
        [string]$ActionId,
        [string]$Operation,
        [string]$Result,
        [string]$Version,
        [int]$DurationSeconds
    )
    $logPath = Get-FluLogPath
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $version = if ([string]::IsNullOrEmpty($Version)) { '-' } else { $Version }
    $duration = if ($DurationSeconds -eq 0 -and $Result -eq 'success') { '-' } else { $DurationSeconds.ToString() }

    # Write header if file doesn't exist
    if (-not (Test-Path $logPath)) {
        "timestamp`taction_id`toperation`tresult`tversion`tduration_seconds" | Out-File -FilePath $logPath -Encoding utf8
    }

    "$timestamp`t$ActionId`t$Operation`t$Result`t$version`t$duration" | Out-File -FilePath $logPath -Encoding utf8 -Append
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

    # Step 1: Fetch module with .ps1->.sh fallback (per D-02, D-03, D-04)
    $scriptContent = $null
    if ($Script:FluIsWindows) {
        # Try .ps1 first (Windows-native PowerShell module)
        $scriptContent = Invoke-FluModuleFetch -ActionId $ActionId -Extension 'ps1'
        if (-not $scriptContent) {
            # Fall back to .sh via WSL
            Write-Host "  $($Script:TUI_DIM)[WSL fallback]$($Script:TUI_RESET) Trying .sh module..."
            $scriptContent = Invoke-FluModuleFetch -ActionId $ActionId -Extension 'sh'
        }
    } else {
        $scriptContent = Invoke-FluModuleFetch -ActionId $ActionId -Extension 'sh'
    }
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
        # No WSL/bash -- graceful message per D-06
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

    # Track execution start time for logging
    $executionStartTime = Get-Date

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

    # Execution logging (per D-10, D-12)
    $durationSeconds = [int](Get-Date).Subtract($executionStartTime).TotalSeconds
    Write-FluExecutionLog -ActionId $ActionId `
        -Operation $(ConvertFrom-FluActionOperation -ActionId $ActionId) `
        -Result $(if ($exitCode -eq 0) { 'success' } else { 'fail' }) `
        -Version $metadata.Version `
        -DurationSeconds $durationSeconds

    return [PSCustomObject]@{
        ExitCode   = $exitCode
        Stdout     = $stdout
        Stderr     = $stderr
        ModuleName = $metadata.Name
        Success    = ($exitCode -eq 0)
    }
}

# ---------------------------------------------------------------------------
# Section 9: Recovery Hint Mapper (Get-FluRecoveryHint)
# ---------------------------------------------------------------------------

function Get-FluRecoveryHint {
    <#
    .SYNOPSIS
    Map exit code to actionable recovery hint.
    PowerShell port of _flu_display_recovery_hints().

    .PARAMETER ExitCode
    Module exit code.
    .PARAMETER Stderr
    Module stderr content for pattern matching.
    #>
    param([int]$ExitCode, [string]$Stderr)

    switch ($ExitCode) {
        124 {
            return "The operation timed out. Try again with a faster connection or check if the service is responsive."
        }
        126 {
            return "The module script could not be executed. This may indicate a corrupted download. Try running again."
        }
        127 {
            return "A required command was not found. Check that all dependencies are installed for this module."
        }
        1 {
            if ($Stderr -match 'curl|wget|fetch|Invoke-WebRequest') {
                return "Network error -- unable to reach the server. Check your internet connection."
            } elseif ($Stderr -match 'Permission denied|permission denied') {
                return "Permission denied -- try running with elevated privileges."
            } elseif ($Stderr -match 'not found|Not found') {
                return "A required dependency was not found. Check that all dependencies are installed."
            } else {
                return "Module exited with code 1. Check the output above for details. You can re-run this operation."
            }
        }
        6 { return "Network error -- unable to reach the server. Check your internet connection." }
        7 { return "Network error -- unable to reach the server. Check your internet connection." }
        22 { return "Network error -- unable to reach the server. Check your internet connection." }
        28 { return "Network error -- unable to reach the server. Check your internet connection." }
        default {
            return "Module exited with code $ExitCode. Check the output above for details. You can re-run this operation."
        }
    }
}

# ---------------------------------------------------------------------------
# Section 10: Result Display (Write-FluModuleResult)
# ---------------------------------------------------------------------------

function Write-FluModuleResult {
    <#
    .SYNOPSIS
    Display module execution results in a box-rendered modal.
    PowerShell port of flu_module_display_result().

    .PARAMETER Result
    Result object from Invoke-FluModuleExecute (with ExitCode, Stdout, Stderr, ModuleName).

    .DESCRIPTION
    Success (exit 0): green [OK] status with module stdout content.
    Failure (exit != 0): red [X] status with exit code, stderr, and recovery hints.
    User presses any key to dismiss the modal.

    Matching flu_module_display_result() behaviors:
      - Box-rendered modal with status-colored title
      - Content rendered inside box with truncation
      - Recovery hints on failure
      - "Press any key to return to menu" footer
      - Manages its own TUI lifecycle
    #>
    param($Result)

    if (-not $Result) { return }

    Initialize-Tui
    Clear-TuiScreen

    $termRows = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
    $termCols = try { $Host.UI.RawUI.WindowSize.Width } catch { 80 }

    $boxWidth = 70
    if ($boxWidth -gt ($termCols - 4)) { $boxWidth = $termCols - 4 }
    $boxHeight = $termRows - 4
    $boxX = [Math]::Max(0, [Math]::Floor(($termCols - $boxWidth) / 2))
    $boxY = 2
    $innerWidth = $boxWidth - 4

    # Build status title
    if ($Result.Success) {
        $title = "[OK] $($Result.ModuleName) -- Complete"
        $titleColor = $Script:TUI_GREEN
    } else {
        $title = "[X] $($Result.ModuleName) -- Failed (exit: $($Result.ExitCode))"
        $titleColor = $Script:TUI_RED
    }

    Write-TuiBox -X $boxX -Y $boxY -Width $boxWidth -Height $boxHeight `
        -Title "$titleColor$title$($Script:TUI_RESET)"

    # Render output content
    $content = if ($Result.Success) { $Result.Stdout } else { $Result.Stderr }
    $contentRow = $boxY + 3
    $maxRow = $boxY + $boxHeight - 4

    if ($content) {
        $contentLines = $content -split "`n"
        foreach ($line in $contentLines) {
            if ($contentRow -ge $maxRow) { break }
            $truncated = if ($line.Length -gt $innerWidth) { $line.Substring(0, $innerWidth) } else { $line }
            Write-TuiAt -Row $contentRow -Col ($boxX + 2)
            Write-Host $truncated -NoNewline
            $contentRow++
        }
    } elseif (-not $Result.Success) {
        Write-TuiAt -Row $contentRow -Col ($boxX + 2)
        Write-Host "$($Script:TUI_YELLOW)Module exited with code $($Result.ExitCode) but produced no error output.$($Script:TUI_RESET)" -NoNewline
        $contentRow++
    }

    # Recovery hints on failure
    if (-not $Result.Success) {
        $contentRow++
        $hint = Get-FluRecoveryHint -ExitCode $Result.ExitCode -Stderr $Result.Stderr
        if ($hint) {
            Write-TuiAt -Row $contentRow -Col ($boxX + 2)
            Write-Host "$($Script:TUI_YELLOW)-> $hint$($Script:TUI_RESET)" -NoNewline
        }
    }

    # Footer
    $footerRow = $boxY + $boxHeight - 2
    Write-TuiAt -Row $footerRow -Col ($boxX + 2)
    Write-Host "$($Script:TUI_DIM)Press any key to return to menu$($Script:TUI_RESET)" -NoNewline

    # Wait for keypress
    Read-TuiKey | Out-Null
    Restore-Tui
}

# ---------------------------------------------------------------------------
# Section 11: Batch Execution Functions (Plan 14-02 -- CLI batch mode)
# ---------------------------------------------------------------------------

function Invoke-FluBatchRun {
    <#
    .SYNOPSIS
    Non-interactive batch module execution (matching flu_batch_run).
    PowerShell port of flu_batch_run() from modules.sh lines 739-947.

    .PARAMETER ActionIds
    Array of action IDs to execute in batch.

    .PARAMETER Flags
    Batch flags: "yes" for --yes mode (skip confirmations).

    .DESCRIPTION
    Validates each action ID against menu.db, fetches and executes
    each module sequentially, prints results, and returns exit code.
    Continues on failure -- collects all results before final summary.
    Exit 0 if all succeed, exit 1 if any fail.

    Threat mitigation T-14-02-01: action IDs validated against menu.db.
    #>
    param([string[]]$ActionIds, [string]$Flags)

    $ok = 0
    $fail = 0

    if ($ActionIds.Count -eq 0) {
        Write-Error "Error: no action IDs provided"
        return 1
    }

    $menuFile = "$Script:FLU_SCRIPT_DIR\menu.db"

    foreach ($aid in $ActionIds) {
        if ([string]::IsNullOrEmpty($aid)) { continue }

        # Validate action_id against menu.db (T-14-02-01: mitigate)
        $isCommunity = $aid -match '^community/'
        if (-not $isCommunity -and (Test-Path $menuFile)) {
            $validActions = Get-Content $menuFile | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object { ($_ -split '\|')[3].Trim() }
            $valid = $validActions -contains $aid
            if (-not $valid) {
                Write-Host "[X] $aid -- Unknown action ID"
                $fail++
                continue
            }
        }

        Write-Host "> $aid"

        # Fetch module via the resolution pipeline
        $scriptContent = $null
        if ($Script:FluIsWindows) {
            $scriptContent = Invoke-FluModuleFetch -ActionId $aid -Extension 'ps1'
        }
        if (-not $scriptContent) {
            $scriptContent = Invoke-FluModuleFetch -ActionId $aid
        }

        if (-not $scriptContent) {
            Write-Host "[X] $aid -- Fetch failed"
            $fail++
            continue
        }

        # Parse metadata
        $metadata = ConvertFrom-FluModuleMetadata -ScriptContent $scriptContent
        if (-not $metadata) {
            Write-Host "[X] $aid -- Metadata parse error"
            $fail++
            continue
        }

        # Check for @params -- reject in --yes mode (D-07)
        if (-not [string]::IsNullOrEmpty($metadata.Params)) {
            if ($Flags -eq 'yes') {
                Write-Host "[X] $aid -- Requires parameters, use interactive mode"
                $fail++
                continue
            } else {
                Write-Host "[!] $aid -- Requires parameters, skipping"
                $fail++
                continue
            }
        }

        # Execute module
        $startTime = Get-Date
        $tempScript = [System.IO.Path]::GetTempFileName() + '.ps1'
        Set-Content -Path $tempScript -Value $scriptContent -NoNewline

        try {
            if ($Script:FluIsWindows) {
                $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-File', $tempScript) -NoNewWindow -Wait -PassThru
                $exitCode = $process.ExitCode
            } else {
                # Cross-platform: use pwsh if available, otherwise skip
                if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                    $process = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-File', $tempScript) -NoNewWindow -Wait -PassThru
                    $exitCode = $process.ExitCode
                } else {
                    Write-Host "[!] $aid -- No PowerShell available to execute module"
                    $exitCode = 1
                }
            }
        } catch {
            $exitCode = 1
        }

        Remove-Item $tempScript -ErrorAction SilentlyContinue
        $durationSeconds = [int](Get-Date).Subtract($startTime).TotalSeconds

        # Log execution
        $operation = ConvertFrom-FluActionOperation -ActionId $aid
        $result = if ($exitCode -eq 0) { 'success' } else { 'fail' }
        Write-FluExecutionLog -ActionId $aid -Operation $operation -Result $result -Version $metadata.Version -DurationSeconds $durationSeconds

        # Print result
        if ($exitCode -eq 0) {
            Write-Host "[OK] $aid -- Complete"
            $ok++
        } else {
            Write-Host "[X] $aid -- Failed (exit $exitCode)"
            $fail++
        }
    }

    # Summary
    Write-Host ""
    Write-Host "$ok succeeded, $fail failed"

    return $(if ($fail -gt 0) { 1 } else { 0 })
}

function Invoke-FluBatchList {
    <#
    .SYNOPSIS
    List available modules in batch mode (matching flu_batch_list).
    PowerShell port of flu_batch_list() from modules.sh lines 961-1050+.

    .PARAMETER JsonMode
    If set, output as JSON array. Otherwise, plain text table.

    .DESCRIPTION
    Reads menu.db and (optionally) community registry and outputs
    formatted table or JSON array of available modules.
    #>
    param([switch]$JsonMode)

    $menuFile = "$Script:FLU_SCRIPT_DIR\menu.db"
    if (-not (Test-Path $menuFile)) {
        Write-Error "Menu database not found: $menuFile"
        return 1
    }

    if ($JsonMode) {
        # JSON output
        $entries = @()
        Get-Content $menuFile | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Count -ge 4) {
                $entries += [PSCustomObject]@{
                    category    = $parts[0].Trim()
                    subcategory = $parts[1].Trim()
                    name        = $parts[2].Trim()
                    action_id   = $parts[3].Trim()
                }
            }
        }
        # Try community modules
        try {
            $registryJson = Invoke-FluRegistryFetch -ErrorAction SilentlyContinue
            if ($registryJson) {
                $communityEntries = $registryJson | ConvertFrom-Json
                foreach ($entry in $communityEntries) {
                    $entries += [PSCustomObject]@{
                        category    = "Community Modules"
                        subcategory = $entry.category
                        name        = $entry.name
                        action_id   = "community/$($entry.action_id)"
                    }
                }
            }
        } catch {}

        Write-Host ($entries | ConvertTo-Json -Depth 3)
    } else {
        # Plain text table
        Write-Host ("{0,-20} {1,-16} {2,-40} {3}" -f "Category", "Subcategory", "Name", "Action ID")
        Write-Host ("{0,-20} {1,-16} {2,-40} {3}" -f "--------", "-----------", "----", "---------")
        Get-Content $menuFile | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object {
            $parts = $_ -split '\|'
            if ($parts.Count -ge 4) {
                Write-Host ("{0,-20} {1,-16} {2,-40} {3}" -f $parts[0].Trim(), $parts[1].Trim(), $parts[2].Trim(), $parts[3].Trim())
            }
        }
        # Try community modules
        try {
            $registryJson = Invoke-FluRegistryFetch -ErrorAction SilentlyContinue
            if ($registryJson) {
                Write-Host "`n--- Community Modules ---"
                $communityEntries = $registryJson | ConvertFrom-Json
                foreach ($entry in $communityEntries) {
                    Write-Host ("{0,-20} {1,-16} {2,-40} {3}" -f "Community Modules", $entry.category, $entry.name, "community/$($entry.action_id)")
                }
            }
        } catch {}
    }
}
