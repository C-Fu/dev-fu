# ============================================================
# modules.Tests.ps1 — Pester tests for modules.ps1
#
# Run: pwsh -Command "Invoke-Pester ./flu-sh/modules.Tests.ps1"
# ============================================================

BeforeAll {
    # Mock TUI constants that modules.ps1 expects
    $Script:TUI_RESET = "`e[0m"
    $Script:TUI_GREEN = "`e[32m"
    $Script:TUI_DIM = "`e[2m"
    $Script:TUI_YELLOW = "`e[33m"
    $Script:TUI_RED = "`e[31m"

    # Dot-source the module under test
    . "$PSScriptRoot/modules.ps1"

    # Temp directories for cache
    $Script:TestCacheDir = Join-Path $env:TEMP "flu-test-cache-$(Get-Random)"
    $Script:FLU_CACHE_DIR = $Script:TestCacheDir
}

AfterAll {
    # Cleanup temp directories
    if (Test-Path $Script:TestCacheDir) {
        Remove-Item -Path $Script:TestCacheDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Task 1: Module Caching Tests
# ============================================================

Describe "Get-FluModuleCachePath" {
    It "returns a path under FLU_CACHE_DIR with the action ID" {
        $path = Get-FluModuleCachePath -ActionId "install_python"
        $path | Should -Not -BeNullOrEmpty
        $path | Should -BeLike "$Script:FLU_CACHE_DIR*"
        $path | Should -EndWith ".ps1"
    }

    It "replaces slashes with underscores in safeId" {
        $path = Get-FluModuleCachePath -ActionId "install/python"
        $path | Should -BeLike "*install_python.ps1"
    }

    It "replaces backslashes with underscores in safeId" {
        $path = Get-FluModuleCachePath -ActionId "install\python"
        $path | Should -BeLike "*install_python.ps1"
    }
}

Describe "Write-FluModuleCache and Read-FluModuleCache" {
    BeforeEach {
        $Script:TestActionId = "test_module_$(Get-Random)"
        $Script:TestContent = "#!/usr/bin/env sh`n# @name: Test Module`n# @version: 1.0`necho hello"
    }

    AfterEach {
        $cachePath = Get-FluModuleCachePath -ActionId $Script:TestActionId
        if (Test-Path $cachePath) { Remove-Item $cachePath -Force -ErrorAction SilentlyContinue }
    }

    It "writes content to cache and reads it back" {
        Write-FluModuleCache -ActionId $Script:TestActionId -Content $Script:TestContent
        $read = Read-FluModuleCache -ActionId $Script:TestActionId
        $read | Should -Be $Script:TestContent
    }

    It "creates the cache directory if it does not exist" {
        $newDir = Join-Path $env:TEMP "flu-new-cache-$(Get-Random)"
        try {
            $originalDir = $Script:FLU_CACHE_DIR
            $Script:FLU_CACHE_DIR = $newDir

            Write-FluModuleCache -ActionId $Script:TestActionId -Content $Script:TestContent
            Test-Path $newDir | Should -Be $true

            $Script:FLU_CACHE_DIR = $originalDir
        } finally {
            if (Test-Path $newDir) { Remove-Item $newDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It "returns null for non-existent cache" {
        $read = Read-FluModuleCache -ActionId "nonexistent_$(Get-Random)"
        $read | Should -Be $null
    }
}

Describe "Test-FluModuleCache" {
    It "returns false when cache file does not exist" {
        $result = Test-FluModuleCache -ActionId "nonexistent_$(Get-Random)"
        $result | Should -Be $false
    }

    It "returns false when cache file is empty" {
        $actionId = "empty_test_$(Get-Random)"
        $cachePath = Get-FluModuleCachePath -ActionId $actionId
        $cacheDir = Split-Path $cachePath -Parent
        if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        New-Item -ItemType File -Path $cachePath -Force | Out-Null
        $result = Test-FluModuleCache -ActionId $actionId
        $result | Should -Be $false
    }

    It "returns true when cache is recent (within TTL)" {
        $actionId = "recent_test_$(Get-Random)"
        Write-FluModuleCache -ActionId $actionId -Content "#test content"
        $result = Test-FluModuleCache -ActionId $actionId
        $result | Should -Be $true
    }

    It "returns false when cache is expired (past TTL)" {
        $actionId = "expired_test_$(Get-Random)"
        Write-FluModuleCache -ActionId $actionId -Content "#test content"

        # Manually set LastWriteTime to far in the past
        $cachePath = Get-FluModuleCachePath -ActionId $actionId
        $pastDate = (Get-Date).AddHours(-24)  # 24h ago, well past 6h TTL
        (Get-Item $cachePath).LastWriteTime = $pastDate

        $result = Test-FluModuleCache -ActionId $actionId
        $result | Should -Be $false
    }
}

Describe "Invoke-FluModuleSha256" {
    It "returns a 64-character hex string" {
        $hash = Invoke-FluModuleSha256 -Content "hello world"
        $hash | Should -Not -BeNullOrEmpty
        $hash.Length | Should -Be 64
    }

    It "returns lowercase hex characters" {
        $hash = Invoke-FluModuleSha256 -Content "hello world"
        $hash | Should -Match '^[a-f0-9]{64}$'
    }

    It "returns consistent results for same content" {
        $hash1 = Invoke-FluModuleSha256 -Content "consistent content"
        $hash2 = Invoke-FluModuleSha256 -Content "consistent content"
        $hash1 | Should -Be $hash2
    }

    It "returns different results for different content" {
        $hash1 = Invoke-FluModuleSha256 -Content "content A"
        $hash2 = Invoke-FluModuleSha256 -Content "content B"
        $hash1 | Should -Not -Be $hash2
    }
}

Describe "Test-FluModuleChecksum" {
    It "returns true when checksum matches manifest" {
        # Mock the manifest fetch to return a known checksum
        Mock Invoke-WebRequest {
            return @{ Content = "abc123def456  install_python.sh" }
        } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $content = "# test script content"
        $result = Test-FluModuleChecksum -ActionId "install_python" -Content $content
        $result | Should -Be $true
    }

    It "returns false when checksum mismatches manifest" {
        # We'll need a real hash — this test checks the logic path
        # Mock the manifest fetch
        Mock Invoke-WebRequest {
            return @{ Content = "0000000000000000000000000000000000000000000000000000000000000000  install_python.sh" }
        } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $content = "# some content that wont match all zeros"
        $result = Test-FluModuleChecksum -ActionId "install_python" -Content $content
        $result | Should -Be $false
    }

    It "returns true with warning when manifest fetch fails" {
        Mock Invoke-WebRequest { throw "Network error" } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $content = "# test content"
        $result = Test-FluModuleChecksum -ActionId "install_python" -Content $content
        $result | Should -Be $true
    }

    It "returns true with warning when no checksum entry for action ID" {
        Mock Invoke-WebRequest {
            return @{ Content = "abc123  some_other_module.sh" }
        } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $content = "# test content"
        $result = Test-FluModuleChecksum -ActionId "install_python" -Content $content
        $result | Should -Be $true
    }
}

Describe "Invoke-FluModuleFetch (cache + checksum integration)" {
    It "returns cached content without making network calls" {
        $actionId = "cached_fetch_$(Get-Random)"
        Write-FluModuleCache -ActionId $actionId -Content "# cached content"

        # Mock Invoke-WebRequest to fail if called
        Mock Invoke-WebRequest { throw "Should not reach network" }

        $result = Invoke-FluModuleFetch -ActionId $actionId
        $result | Should -Be "# cached content"
    }

    It "rejects content when checksum mismatches" {
        $actionId = "bad_checksum_$(Get-Random)"

        # Mock Resolve-FluModuleUrl
        Mock Resolve-FluModuleUrl { return "https://example.com/$actionId.sh" }

        # Mock Invoke-WebRequest for fetch
        Mock Invoke-WebRequest { return @{ Content = "# compromised content" } }
            -ParameterFilter { $Uri -like "https://example.com/*" }

        # Mock manifest fetch with wrong hash
        Mock Invoke-WebRequest {
            return @{ Content = "0000000000000000000000000000000000000000000000000000000000000000  $actionId.sh" }
        } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $result = Invoke-FluModuleFetch -ActionId $actionId
        $result | Should -Be $null
    }

    It "stores fetched content to cache after valid checksum" {
        $actionId = "store_to_cache_$(Get-Random)"
        $testContent = @"
#!/usr/bin/env sh
# @name: Test
# @version: 1.0
echo hello
"@
        # Mock dependencies
        Mock Resolve-FluModuleUrl { return "https://example.com/$actionId.sh" }
        Mock Invoke-WebRequest { return @{ Content = $testContent } }
            -ParameterFilter { $Uri -like "https://example.com/*" }

        $hash = Invoke-FluModuleSha256 -Content $testContent
        Mock Invoke-WebRequest {
            return @{ Content = "$hash  $actionId.sh" }
        } -ParameterFilter { $Uri -like "*MANIFEST.sha256" }

        $result = Invoke-FluModuleFetch -ActionId $actionId
        $result | Should -Be $testContent

        # Verify cache exists
        $cachePath = Get-FluModuleCachePath -ActionId $actionId
        Test-Path $cachePath | Should -Be $true
        (Get-Content $cachePath -Raw) | Should -Be $testContent
    }
}
