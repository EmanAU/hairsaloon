param([string]$Phone, [string]$Password)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $testArguments = @('test', 'test/portrait_audit_flow_test.dart', '--dart-define=EXPORT_SCREENSHOTS=true', '--reporter', 'expanded')
    if ($Phone) { $testArguments += "--dart-define=QA_PHONE=$Phone" }
    if ($Password) { $testArguments += "--dart-define=QA_PASSWORD=$Password" }
    & flutter @testArguments
    $testExitCode = $LASTEXITCODE
    $bundledPython = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (Test-Path -LiteralPath $bundledPython) {
        & $bundledPython scripts/package_portrait_review.py
    } else {
        & python scripts/package_portrait_review.py
    }
    if ($LASTEXITCODE -ne 0) { throw 'Could not package portrait screenshots.' }
    if ($testExitCode -ne 0) { throw 'Portrait QA found issues; completed coverage manifests and photos are packaged for review.' }
    Write-Host 'Tablet photos: screenshots/tablet_photos/. Mobile photos: screenshots/mobile_photos/.'
} finally {
    Pop-Location
}
