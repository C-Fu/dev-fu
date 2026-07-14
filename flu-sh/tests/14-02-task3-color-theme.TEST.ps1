#!/usr/bin/env pwsh
# ============================================================
# Test: Color Theme Support (Plan 14-02, Task 3)
# ============================================================
# Validates that Apply-FluTheme function exists in tui.ps1
# and handles dark, light, monochrome themes.
#
# Run: pwsh -NoProfile -File tests/14-02-task3-color-theme.TEST.ps1
# ============================================================

$exitCode = 0

# Test 1: Apply-FluTheme function exists in tui.ps1
Write-Host -NoNewline "Test 1: Apply-FluTheme function definition ... "
$funcFound = Select-String -Path "$PSScriptRoot\..\tui.ps1" -Pattern 'function Apply-FluTheme' -SimpleMatch
if ($funcFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — Apply-FluTheme function not found in tui.ps1"
    $exitCode = 1
}

# Test 2: Apply-FluTheme handles 'dark' theme
Write-Host -NoNewline "Test 2: dark theme case ... "
$darkFound = Select-String -Path "$PSScriptRoot\..\tui.ps1" -Pattern "'dark'" -SimpleMatch
if ($darkFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — dark theme case not found"
    $exitCode = 1
}

# Test 3: Apply-FluTheme handles 'light' theme
Write-Host -NoNewline "Test 3: light theme case ... "
$lightFound = Select-String -Path "$PSScriptRoot\..\tui.ps1" -Pattern "'light'" -SimpleMatch
if ($lightFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — light theme case not found"
    $exitCode = 1
}

# Test 4: Apply-FluTheme handles 'monochrome' theme
Write-Host -NoNewline "Test 4: monochrome theme case ... "
$monoFound = Select-String -Path "$PSScriptRoot\..\tui.ps1" -Pattern "'monochrome'" -SimpleMatch
if ($monoFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — monochrome theme case not found"
    $exitCode = 1
}

# Test 5: Apply-FluTheme has default/unknown fallback
Write-Host -NoNewline "Test 5: default/unknown fallback ... "
$defaultFound = Select-String -Path "$PSScriptRoot\..\tui.ps1" -Pattern 'default' -SimpleMatch
if ($defaultFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — default fallback not found"
    $exitCode = 1
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
}
exit $exitCode
