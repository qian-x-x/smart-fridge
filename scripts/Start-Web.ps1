#Requires -Version 7.0
<#
.SYNOPSIS
    启动 Web 容器：托管 Flutter release 产物并把 /api 同源代理到网关。

.DESCRIPTION
    发布到 127.0.0.1:3030；对外访问统一用 3000，
    局域网需要再执行 scripts/Enable-LanAccess.ps1 或 scripts/lan-bridge.py。

.PARAMETER Build
    先执行 flutter build web --release 再启动容器。

.PARAMETER Port
    容器在宿主机上的端口，默认 3030。
#>
[CmdletBinding()]
param(
    [switch]$Build,
    [int]$Port = 3030
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$webRoot = Join-Path $projectRoot 'apps/fridge-app'
$config = Join-Path $projectRoot 'infra/web/nginx.conf'
$dist = Join-Path $webRoot 'build/web'

if ($Build) {
    Push-Location $webRoot
    try {
        $env:HTTP_PROXY = ''
        $env:HTTPS_PROXY = ''
        flutter build web --release
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $dist 'index.html'))) {
    throw "未找到 $dist/index.html，请先执行 flutter build web --release 或加 -Build"
}

$dockerPath = $dist -replace '\\', '/'
$configPath = $config -replace '\\', '/'

docker rm -f sf-web 2>$null | Out-Null
docker run -d --name sf-web --network smart-fridge -p "${Port}:80" `
    -v "${configPath}:/etc/nginx/conf.d/default.conf:ro" `
    -v "${dockerPath}:/usr/share/nginx/html:ro" `
    nginx:alpine | Out-Null

Start-Sleep -Seconds 3
$status = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/" -UseBasicParsing -TimeoutSec 10).StatusCode
if ($status -ne 200) {
    throw "Web 容器未就绪，状态码 $status"
}
$apiStatus = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/api/v1/fridges/ping" -UseBasicParsing -TimeoutSec 10 -SkipHttpErrorCheck).StatusCode

Write-Output "Web 已启动：http://127.0.0.1:$Port（/api 代理返回 $apiStatus，401 表示网关已连通）"
Write-Output '局域网：管理员运行 scripts/Enable-LanAccess.ps1，或 python scripts/lan-bridge.py 3000=' + $Port
