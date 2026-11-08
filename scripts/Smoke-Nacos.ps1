#Requires -Version 7.0
<#
.SYNOPSIS
    Nacos 注册发现与外置配置的真实链路验收。

.DESCRIPTION
    覆盖评分表 B2（注册与发现）、B3（外置配置）、F4（动态刷新）三项证据：
    1. 6 个服务在 Nacos 的 SMART_FRIDGE 分组下注册，且实例健康；
    2. 网关按服务名转发请求成功（lb:// 生效，不再依赖固定地址）；
    3. fridge-service 从 Nacos 读取 expiring-threshold-days，改配置后接口结果随之变化，无需重启。

    脚本自建账号、家庭、冰箱与一份 5 天后到期的食材，不依赖既有数据；
    结束时把配置恢复为默认值 3。
#>
[CmdletBinding()]
param(
    [string]$Gateway = 'http://127.0.0.1:8080',
    [string]$Nacos = 'http://127.0.0.1:8848',
    [string]$DataId = 'fridge-service.yaml',
    [string]$Group = 'SMART_FRIDGE',
    [string]$OutFile = 'docs/reviews/evidence/2026-11-08-n1/api-acceptance.json'
)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
$stamp = Get-Date -Format 'MMddHHmmss'
$today = (Get-Date).Date

function Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; pass = $Pass; detail = $Detail })
    $mark = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Output ("{0}  {1} :: {2}" -f $mark, $Name, $Detail)
}

function Invoke-Call {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers = @{},
        $Body = $null,
        [hashtable]$Form = $null
    )
    $params = @{ Uri = $Uri; Method = $Method; UseBasicParsing = $true; TimeoutSec = 30; SkipHttpErrorCheck = $true }
    if ($null -ne $Form) {
        $params.Body = $Form
    } elseif ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        $params.ContentType = 'application/json'
    }
    if ($Headers.Count -gt 0) { $params.Headers = $Headers }
    $response = Invoke-WebRequest @params
    $json = $null
    try { $json = $response.Content | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $json; Raw = $response.Content }
}

function Publish-Threshold {
    param([int]$Days)
    $content = '{"smart-fridge": {"fridge": {"expiring-threshold-days": ' + $Days + '}}}'
    Invoke-Call -Method POST -Uri "$Nacos/nacos/v1/cs/configs" -Form @{
        dataId  = $DataId
        group   = $Group
        type    = 'yaml'
        content = $content
    }
}

Write-Output "== Nacos 验收 via $Gateway / $Nacos (run $stamp) =="

# 1. 注册证据
$services = Invoke-Call -Method GET -Uri "$Nacos/nacos/v1/ns/catalog/services?hasIpCount=true&withInstances=false&pageNo=1&pageSize=50&namespaceId=public&groupName=$Group"
$names = @($services.Body.serviceList | ForEach-Object { $_.name })
Check 'nacos-reachable' ($services.Status -eq 200) "status=$($services.Status)"
Check 'six-services-registered' ($names.Count -eq 6) "count=$($names.Count) names=$($names -join ',')"
Check 'gateway-registered' ($names -contains 'gateway-service') "services=$($names -join ',')"
Check 'no-notification-service' (-not ($names -contains 'notification-service')) "services=$($names -join ',')"

$allHealthy = @($services.Body.serviceList | Where-Object { $_.healthyInstanceCount -lt 1 })
Check 'all-instances-healthy' ($allHealthy.Count -eq 0) "unhealthy=$($allHealthy.Count)"

$fridgeInstances = Invoke-Call -Method GET -Uri "$Nacos/nacos/v1/ns/instance/list?serviceName=fridge-service&groupName=$Group&namespaceId=public"
Check 'fridge-instance-address' (@($fridgeInstances.Body.hosts).Count -ge 1) "hosts=$(@($fridgeInstances.Body.hosts | ForEach-Object { $_.ip + ':' + $_.port }) -join ',')"

# 2. 经网关按服务名转发（lb://）
$owner = Invoke-Call -Method POST -Uri "$Gateway/api/v1/auth/register" -Body @{
    username = "nacos$stamp"; displayName = 'Nacos 验收'; password = 'Accept2026!'
}
Check 'gateway-routes-auth-by-name' ($owner.Status -eq 201) "status=$($owner.Status)"
$token = $owner.Body.data.accessToken

$family = Invoke-Call -Method POST -Uri "$Gateway/api/v1/families" -Headers @{ Authorization = "Bearer $token" } -Body @{ name = "Nacos 验收家庭 $stamp" }
$fridge = Invoke-Call -Method POST -Uri "$Gateway/api/v1/fridges" -Headers @{ Authorization = "Bearer $token" } -Body @{ familyId = $family.Body.data.id; name = "Nacos 验收冰箱 $stamp" }
$fridgeId = $fridge.Body.data.id
$zoneId = $fridge.Body.data.zones[0].id
$containerId = $fridge.Body.data.zones[0].containers[0].id
Check 'gateway-routes-fridge-by-name' ($fridgeId -gt 0) "status=$($fridge.Status) fridgeId=$fridgeId"

$food = Invoke-Call -Method POST -Uri "$Gateway/api/v1/foods" -Headers @{ Authorization = "Bearer $token" } -Body @{
    fridgeId       = $fridgeId
    zoneId         = $zoneId
    containerId    = $containerId
    name           = 'Nacos 阈值样本'
    category       = '奶制品'
    quantity       = 1
    unit           = '盒'
    productionDate = $today.AddDays(-5).ToString('yyyy-MM-dd')
    expiresOn      = $today.AddDays(5).ToString('yyyy-MM-dd')
}
Check 'seed-food-created' ($food.Status -eq 201) "status=$($food.Status) remainingDays=$($food.Body.data.remainingDays)"

function Get-Expiring {
    $result = Invoke-Call -Method GET -Uri "$Gateway/api/v1/foods/$($food.Body.data.id)" -Headers @{ Authorization = "Bearer $token" }
    [pscustomobject]@{ Status = $result.Status; Expiring = $result.Body.data.expiring; Remaining = $result.Body.data.remainingDays }
}

# 3. 外置配置 + 动态刷新：同一份数据，阈值 1 与 10 结论相反
$null = Publish-Threshold -Days 1
Start-Sleep -Seconds 8
$narrow = Get-Expiring
Check 'external-config-narrow-threshold' ($narrow.Expiring -eq $false) "threshold=1 remaining=$($narrow.Remaining) expiring=$($narrow.Expiring)"

$null = Publish-Threshold -Days 10
Start-Sleep -Seconds 8
$wide = Get-Expiring
Check 'refresh-applies-without-restart' ($wide.Expiring -eq $true) "threshold=10 remaining=$($wide.Remaining) expiring=$($wide.Expiring)"

$null = Publish-Threshold -Days 3
Start-Sleep -Seconds 8
$restored = Get-Expiring
Check 'threshold-restored' ($restored.Expiring -eq $false) "threshold=3 remaining=$($restored.Remaining) expiring=$($restored.Expiring)"

$configBack = Invoke-Call -Method GET -Uri "$Nacos/nacos/v1/cs/configs?dataId=$DataId&group=$Group"
Check 'config-persisted' ($configBack.Status -eq 200 -and $configBack.Raw -match 'expiring-threshold-days') "content=$($configBack.Raw)"

$summary = [pscustomobject]@{
    runAt   = (Get-Date).ToString('o')
    gateway = $Gateway
    nacos   = $Nacos
    dataId  = $DataId
    group   = $Group
    total   = $checks.Count
    passed  = @($checks | Where-Object { $_.pass }).Count
    failed  = @($checks | Where-Object { -not $_.pass }).Count
    checks  = $checks
}

$directory = Split-Path -Parent $OutFile
if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8

Write-Output ("`n== {0}/{1} checks passed ==" -f $summary.passed, $summary.total)
if ($summary.failed -gt 0) { exit 1 }
