# @name: Set GitHub Token
# @params: token=text:Enter your GitHub personal access token
# @platforms: windows
# @version: 1.0.0
# @deps:
# @timeout: 30

$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$tokenFile = "$env:USERPROFILE\.config\dev-fu\github-token"
$ghToken = ""

# Check for --token parameter
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '--token' -and ($i + 1) -lt $args.Count) {
        $ghToken = $args[$i + 1]
    }
}

# If no --token provided, prompt interactively
if ([string]::IsNullOrEmpty($ghToken)) {
    $ghToken = Read-Host "Enter GitHub personal access token"
}

# Validate input
if ([string]::IsNullOrEmpty($ghToken)) {
    Write-Host "No token provided — cancelled."
    exit 0
}

# Check for existing token
if (Test-Path $tokenFile) {
    $cur = Get-Content $tokenFile -Raw
    if ($cur.Trim() -eq $ghToken) {
        Write-Host "GitHub token already set at $tokenFile"
        Write-Host "Token: $($ghToken.Substring(0, 4))****$($ghToken.Substring($ghToken.Length - 4))"
        exit 0
    }
}

# Save the token
$tokenDir = Split-Path $tokenFile -Parent
if (-not (Test-Path $tokenDir)) {
    New-Item -ItemType Directory -Path $tokenDir -Force | Out-Null
}
Set-Content -Path $tokenFile -Value $ghToken -NoNewline
# Set ACL to restrict access
icacls $tokenFile /inheritance:r /grant "$env:USERNAME:(R)" /quiet 2>$null

Write-Host "GitHub token saved to $tokenFile"
Write-Host "Note: Token verification skipped (curl not available on all Windows systems)"
