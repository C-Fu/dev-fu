#!/usr/bin/env pwsh
# ============================================================
# Test: CLI Batch Mode for flu.ps1 (Plan 14-02, Task 1)
# ============================================================
# Validates that CLI argument parsing and batch execution
# functions are present in flu.ps1 and modules.ps1.
#
# Run: pwsh -NoProfile -File tests/14-02-task1-cli-batch-mode.TEST.ps1
# ============================================================

$exitCode = 0

# Test 1: flu.ps1 has top-level param() block with CLI flags
Write-Host -NoNewline "Test 1: param() block with CLI flags ... "
$paramFound = Select-String -Path "$PSScriptRoot\..\flu.ps1" -Pattern 'param\(\s*\[string\]\$install' -SimpleMatch
if ($paramFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — param() with CLI flags not found"
    $exitCode = 1
}

# Test 2: flu.ps1 --help usage text
Write-Host -NoNewline "Test 2: --help usage text ... "
$helpFound = Select-String -Path "$PSScriptRoot\..\flu.ps1" -Pattern '--help' -SimpleMatch
if ($helpFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — --help usage text not found"
    $exitCode = 1
}

# Test 3: flu.ps1 has CLI dispatch for -list
Write-Host -NoNewline "Test 3: CLI dispatch for -list ... "
$listFound = Select-String -Path "$PSScriptRoot\..\flu.ps1" -Pattern '\$list' -SimpleMatch
if ($listFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — CLI dispatch for -list not found"
    $exitCode = 1
}

# Test 4: modules.ps1 has Invoke-FluBatchRun
Write-Host -NoNewline "Test 4: Invoke-FluBatchRun ... "
$batchRunFound = Select-String -Path "$PSScriptRoot\..\modules.ps1" -Pattern 'function Invoke-FluBatchRun' -SimpleMatch
if ($batchRunFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — Invoke-FluBatchRun not found"
    $exitCode = 1
}

# Test 5: modules.ps1 has Invoke-FluBatchList
Write-Host -NoNewline "Test 5: Invoke-FluBatchList ... "
$batchListFound = Select-String -Path "$PSScriptRoot\..\modules.ps1" -Pattern 'function Invoke-FluBatchList' -SimpleMatch
if ($batchListFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — Invoke-FluBatchList not found"
    $exitCode = 1
}

# Test 6: TTY reattachment skips in CLI mode
Write-Host -NoNewline "Test 6: CLI mode guard on TTY reattach ... "
$ttyGuardFound = Select-String -Path "$PSScriptRoot\..\flu.ps1" -Pattern '_fluIsCli' -SimpleMatch
if ($ttyGuardFound) {
    Write-Host "PASS"
} else {
    Write-Host "FAIL — _fluIsCli guard not found"
    $exitCode = 1
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
} else {
    Write-Host "SOME TESTS FAILED" -ForegroundColor Red
}
exit $exitCode
