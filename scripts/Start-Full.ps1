param(
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $projectRoot "infra/compose/compose.full.yml"
$envFile = Join-Path $projectRoot "infra/compose/.env"

if (-not (Test-Path -LiteralPath $envFile)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "infra/compose/.env.example") -Destination $envFile
    Write-Host "Created local infrastructure config at infra/compose/.env"
}

docker compose --env-file $envFile -f $composeFile up -d
docker compose --env-file $envFile -f $composeFile ps

Write-Host ""
Write-Host "Sentinel:  http://localhost:8858"
Write-Host "SkyWalking: http://localhost:8088"
Write-Host "Seata:      127.0.0.1:8091"
