param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$flutterProject = (Resolve-Path (Join-Path $projectRoot "apps/fridge-app")).Path
$junctionName = "smart-fridge-flutter-" + [Guid]::NewGuid().ToString("N")
$asciiPath = Join-Path ([IO.Path]::GetTempPath()) $junctionName

if ($asciiPath -match '[^\x00-\x7F]') {
    throw "The temporary path still contains non-ASCII characters: $asciiPath"
}

New-Item -ItemType Junction -Path $asciiPath -Target $flutterProject | Out-Null

try {
    Push-Location $asciiPath
    if ($Clean) {
        & flutter clean
        if ($LASTEXITCODE -ne 0) {
            throw "flutter clean failed"
        }
    }

    & flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get failed"
    }

    & flutter analyze
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed"
    }

    & flutter test
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test failed"
    }

    & flutter build web --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Web build failed"
    }

    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        throw "Android APK build failed"
    }

    Write-Host ""
    Write-Host "APK: $(Join-Path $flutterProject 'build/app/outputs/flutter-apk/app-release.apk')"
    Write-Host "Web: $(Join-Path $flutterProject 'build/web')"
    Write-Host "Android release currently uses the template debug signing key."
}
finally {
    Pop-Location
    if ((Test-Path -LiteralPath $asciiPath) -and
        ((Get-Item -LiteralPath $asciiPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Remove-Item -LiteralPath $asciiPath -Force
    }
}
