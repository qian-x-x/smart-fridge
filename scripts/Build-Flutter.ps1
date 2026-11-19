param(
    [switch]$Clean,
    [switch]$SkipChecks,
    [switch]$SkipWeb
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterProject = (Resolve-Path (Join-Path $projectRoot 'apps/fridge-app')).Path
$asciiPath = Join-Path ([IO.Path]::GetTempPath()) ('smart-fridge-build-' + [Guid]::NewGuid().ToString('N'))
if ($asciiPath -match '[^\x00-\x7F]') {
    throw "The build copy requires an ASCII TEMP path: $asciiPath"
}
$previousPubHost = $env:PUB_HOSTED_URL
try {
    # Pin the existing lock file. A mirror URL must not silently re-resolve it.
    $env:PUB_HOSTED_URL = 'https://pub.dev'
    Push-Location $flutterProject
    try {
        if ($Clean) {
            & flutter clean
            if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
        }
        & flutter pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Locked dependency resolution failed' }
        if (-not $SkipChecks) {
            & dart analyze lib test
            if ($LASTEXITCODE -ne 0) { throw 'Dart analysis failed' }
            & flutter test --no-pub
            if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed' }
        }
        if (-not $SkipWeb) {
            & flutter build web --release --no-pub
            if ($LASTEXITCODE -ne 0) { throw 'Flutter Web build failed' }
        }
    } finally { Pop-Location }

    # A junction can still canonicalize to the non-ASCII workspace in the AOT
    # process. A real source copy keeps every compiler input path ASCII.
    New-Item -ItemType Directory -Path $asciiPath | Out-Null
    & robocopy $flutterProject $asciiPath /E /XD build .dart_tool .gradle .git /XF local.properties /R:1 /W:1 /NFL /NDL /NJH /NJS
    if ($LASTEXITCODE -gt 7) { throw 'ASCII build source copy failed' }
    Push-Location $asciiPath
    try {
        & flutter pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Build-copy dependencies failed' }
        & flutter build apk --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed' }
    } finally { Pop-Location }

    $apkOutput = Join-Path $flutterProject 'build/app/outputs/flutter-apk'
    New-Item -ItemType Directory -Path $apkOutput -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $asciiPath 'build/app/outputs/flutter-apk/app-release.apk') -Destination (Join-Path $apkOutput 'app-release.apk') -Force
    Write-Host "APK: $(Join-Path $apkOutput 'app-release.apk')"
    if (-not $SkipWeb) { Write-Host "Web: $(Join-Path $flutterProject 'build/web')" }
    Write-Host 'Android release uses the template debug signing key; device acceptance is separate.'
    Write-Host "Build copy retained for inspection: $asciiPath"
} finally {
    $env:PUB_HOSTED_URL = $previousPubHost
}
