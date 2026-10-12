$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $flutterBinary = (Get-Command flutter).Source
    $fontDirectory = Join-Path (Split-Path -Parent $flutterBinary) 'cache/artifacts/material_fonts'
    flutter test test/responsive_flow_test.dart --dart-define=EXPORT_SCREENSHOTS=true "--dart-define=FLUTTER_FONT_DIR=$fontDirectory" --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Responsive flow checks failed.' }
    $captureRoot = Join-Path $projectRoot 'screenshots'
    $archiveInputs = @('mobile', 'tablet_portrait', 'tablet_landscape', 'index.html', 'README.md') |
        ForEach-Object { Join-Path $captureRoot $_ } |
        Where-Object { Test-Path -LiteralPath $_ }
    Compress-Archive -LiteralPath $archiveInputs -DestinationPath (Join-Path $captureRoot 'ui-flow.zip') -Force
    Write-Host 'Screenshots updated in screenshots/. Open screenshots/index.html to browse.'
} finally {
    Pop-Location
}
