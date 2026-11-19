param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $projectRoot "infra/compose/compose.core.yml"
$envFile = Join-Path $projectRoot "infra/compose/.env"

if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "infra/compose/.env.example") -Destination $envFile
    Write-Host "Created local infrastructure config at infra/compose/.env"
}

docker compose --env-file $envFile -f $composeFile up -d
docker compose --env-file $envFile -f $composeFile ps

Write-Host ""
Write-Host "Nacos console:  http://localhost:8848/nacos"
Write-Host "MySQL core:     127.0.0.1:3306"
Write-Host "MySQL trade:    127.0.0.1:3307"
Write-Host "Redis:          127.0.0.1:6379"
