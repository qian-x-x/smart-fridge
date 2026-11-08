#Requires -Version 7.0
<#
.SYNOPSIS
    过期食材一键清理与食材信息编辑的真实链路联调。

.DESCRIPTION
    通过 Gateway 访问真实的 auth-family / fridge 服务与 MySQL。
    覆盖：批量清理只处理已过期项、清理流水可撤销、重复清理幂等、
    分类修正落库、陈旧版本冲突、只读成员拒绝、未知资源 404。
    脚本创建独立的验收账号与家庭，不修改既有数据。
#>
[CmdletBinding()]
param(
    [string]$Gateway = 'http://127.0.0.1:8080',
    [string]$OutFile = 'docs/reviews/evidence/2026-11-06-food-ops/api-acceptance.json'
)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
$stamp = Get-Date -Format 'MMddHHmmss'
$today = (Get-Date).Date

function Invoke-Call {
    param(
        [string]$Method,
        [string]$Path,
        [hashtable]$Headers = @{},
        $Body = $null
    )
    $params = @{
        Uri                = "$Gateway$Path"
        Method             = $Method
        UseBasicParsing    = $true
        TimeoutSec         = 30
        SkipHttpErrorCheck = $true
    }
    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
        $params.ContentType = 'application/json'
    }
    if ($Headers.Count -gt 0) {
        $params.Headers = $Headers
    }
    $response = Invoke-WebRequest @params
    $json = $null
    try { $json = $response.Content | ConvertFrom-Json } catch { }
    [pscustomobject]@{ Status = [int]$response.StatusCode; Body = $json; Raw = $response.Content }
}

function Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $checks.Add([pscustomobject]@{ name = $Name; pass = $Pass; detail = $Detail })
    $mark = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Output ("{0}  {1} :: {2}" -f $mark, $Name, $Detail)
}

function Auth($token) { @{ Authorization = "Bearer $token" } }

function New-Account {
    param([string]$Prefix, [string]$Display)
    $username = "$Prefix$stamp"
    $result = Invoke-Call -Method POST -Path '/api/v1/auth/register' -Body @{
        username    = $username
        displayName = $Display
        password    = 'Accept2026!'
    }
    [pscustomobject]@{
        Username = $username
        Status   = $result.Status
        Token    = $result.Body.data.accessToken
    }
}

function Add-Food {
    param(
        [int]$FridgeId,
        [int]$ZoneId,
        [int]$ContainerId,
        [string]$Name,
        [string]$Category,
        [double]$Quantity,
        [string]$Unit,
        [datetime]$ExpiresOn,
        [string]$Token
    )
    $result = Invoke-Call -Method POST -Path '/api/v1/foods' -Headers (Auth $Token) -Body @{
        fridgeId       = $FridgeId
        zoneId         = $ZoneId
        containerId    = $ContainerId
        name           = $Name
        category       = $Category
        quantity       = $Quantity
        unit           = $Unit
        productionDate = $ExpiresOn.AddDays(-10).ToString('yyyy-MM-dd')
        expiresOn      = $ExpiresOn.ToString('yyyy-MM-dd')
    }
    [pscustomobject]@{ Status = $result.Status; Id = $result.Body.data.id; Version = $result.Body.data.version }
}

Write-Output "== 过期清理与食材编辑验收 via $Gateway (run $stamp) =="

$owner = New-Account -Prefix 'foown' -Display '清理验收拥有者'
Check 'register-owner' ($owner.Status -eq 201 -and $owner.Token) "status=$($owner.Status)"

$member = New-Account -Prefix 'fomem' -Display '清理验收成员'
Check 'register-member' ($member.Status -eq 201 -and $member.Token) "status=$($member.Status)"

$family = Invoke-Call -Method POST -Path '/api/v1/families' -Headers (Auth $owner.Token) -Body @{ name = "清理验收家庭 $stamp" }
$familyId = $family.Body.data.id
Check 'create-family' ($familyId -gt 0) "status=$($family.Status) familyId=$familyId"

$join = Invoke-Call -Method POST -Path '/api/v1/families/join' -Headers (Auth $member.Token) -Body @{ inviteCode = $family.Body.data.inviteCode }
Check 'join-family' ($join.Status -eq 200) "status=$($join.Status)"

$fridge = Invoke-Call -Method POST -Path '/api/v1/fridges' -Headers (Auth $owner.Token) -Body @{ familyId = $familyId; name = "清理验收冰箱 $stamp" }
$fridgeId = $fridge.Body.data.id
$zoneId = $fridge.Body.data.zones[0].id
$containerId = $fridge.Body.data.zones[0].containers[0].id
Check 'create-fridge' ($fridgeId -gt 0) "status=$($fridge.Status) fridgeId=$fridgeId"

# 已过期、今天到期、未过期各一份：只有第一个应被清理。
$expired = Add-Food -FridgeId $fridgeId -ZoneId $zoneId -ContainerId $containerId -Name '过期西兰花' -Category '水果' -Quantity 1 -Unit '颗' -ExpiresOn $today.AddDays(-3) -Token $owner.Token
Check 'add-expired-food' ($expired.Status -eq 201) "status=$($expired.Status) id=$($expired.Id)"

$dueToday = Add-Food -FridgeId $fridgeId -ZoneId $zoneId -ContainerId $containerId -Name '今天到期鸡蛋' -Category '蛋类' -Quantity 6 -Unit '个' -ExpiresOn $today -Token $owner.Token
Check 'add-due-today-food' ($dueToday.Status -eq 201) "status=$($dueToday.Status) id=$($dueToday.Id)"

$fresh = Add-Food -FridgeId $fridgeId -ZoneId $zoneId -ContainerId $containerId -Name '新鲜牛奶' -Category '奶制品' -Quantity 2 -Unit '盒' -ExpiresOn $today.AddDays(5) -Token $owner.Token
Check 'add-fresh-food' ($fresh.Status -eq 201) "status=$($fresh.Status) id=$($fresh.Id)"

# 只读成员先不能清理。
$viewerClean = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/discard-expired" -Headers (Auth $member.Token)
Check 'viewer-cannot-clean' ($viewerClean.Status -eq 403) "status=$($viewerClean.Status)"

$clean = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/discard-expired" -Headers (Auth $owner.Token)
Check 'cleanup-accepted' ($clean.Status -eq 200) "status=$($clean.Status)"
Check 'cleanup-counts-only-expired' ($clean.Body.data.count -eq 1) "count=$($clean.Body.data.count) skipped=$($clean.Body.data.skipped)"
Check 'cleanup-returns-snapshot' ($clean.Body.data.foods[0].id -eq $expired.Id -and $clean.Body.data.foods[0].name -eq '过期西兰花') "food=$($clean.Body.data.foods[0].name)"

$stock = Invoke-Call -Method GET -Path "/api/v1/foods?fridgeId=$fridgeId" -Headers (Auth $owner.Token)
$remainingIds = @($stock.Body.data | ForEach-Object { $_.id })
Check 'cleanup-keeps-today-and-fresh' (($remainingIds -contains $dueToday.Id) -and ($remainingIds -contains $fresh.Id)) "remaining=$($remainingIds -join ',')"
Check 'cleanup-removed-expired' (-not ($remainingIds -contains $expired.Id)) "remaining=$($remainingIds -join ',')"

$timeline = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/operations?limit=5" -Headers (Auth $owner.Token)
$discardOps = @($timeline.Body.data | Where-Object { $_.action -eq 'DISCARD' })
Check 'cleanup-writes-discard-record' ($discardOps.Count -eq 1) "discardRecords=$($discardOps.Count)"
Check 'cleanup-record-note' ($discardOps[0].note -eq '过期清理') "note=$($discardOps[0].note)"
Check 'cleanup-record-undoable' ($discardOps[0].undoable -eq $true) "undoable=$($discardOps[0].undoable)"

$cleanAgain = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/discard-expired" -Headers (Auth $owner.Token)
Check 'cleanup-is-idempotent' ($cleanAgain.Status -eq 200 -and $cleanAgain.Body.data.count -eq 0) "status=$($cleanAgain.Status) count=$($cleanAgain.Body.data.count)"

# 分类修正：把误选为「奶制品」的食材改成「饮品」。
$editFreshBody = @{
    zoneId         = $zoneId
    containerId    = $containerId
    name           = '新鲜牛奶'
    category       = '饮品'
    quantity       = 2
    unit           = '盒'
    productionDate = $today.AddDays(-5).ToString('yyyy-MM-dd')
    expiresOn      = $today.AddDays(5).ToString('yyyy-MM-dd')
    version        = $fresh.Version
}

$viewerEdit = Invoke-Call -Method PUT -Path "/api/v1/foods/$($fresh.Id)" -Headers (Auth $member.Token) -Body $editFreshBody
Check 'viewer-cannot-edit' ($viewerEdit.Status -eq 403) "status=$($viewerEdit.Status)"

$edit = Invoke-Call -Method PUT -Path "/api/v1/foods/$($fresh.Id)" -Headers (Auth $owner.Token) -Body $editFreshBody
Check 'edit-category-accepted' ($edit.Status -eq 200) "status=$($edit.Status)"
Check 'edit-category-persisted' ($edit.Body.data.category -eq '饮品') "category=$($edit.Body.data.category)"
Check 'edit-bumps-version' ($edit.Body.data.version -eq ($fresh.Version + 1)) "version=$($edit.Body.data.version)"

$afterEdit = Invoke-Call -Method GET -Path "/api/v1/foods/$($fresh.Id)" -Headers (Auth $owner.Token)
Check 'edit-visible-on-read' ($afterEdit.Body.data.category -eq '饮品') "category=$($afterEdit.Body.data.category)"

$stale = Invoke-Call -Method PUT -Path "/api/v1/foods/$($fresh.Id)" -Headers (Auth $owner.Token) -Body $editFreshBody
Check 'edit-rejects-stale-version' ($stale.Status -eq 409) "status=$($stale.Status) code=$($stale.Body.code)"

$unknownFridge = Invoke-Call -Method POST -Path '/api/v1/fridges/999999/discard-expired' -Headers (Auth $owner.Token)
Check 'cleanup-unknown-fridge-404' ($unknownFridge.Status -eq 404) "status=$($unknownFridge.Status)"

$unknownFood = Invoke-Call -Method PUT -Path '/api/v1/foods/999999' -Headers (Auth $owner.Token) -Body $editFreshBody
Check 'edit-unknown-food-404' ($unknownFood.Status -eq 404) "status=$($unknownFood.Status)"

$summary = [pscustomobject]@{
    runAt   = (Get-Date).ToString('o')
    gateway = $Gateway
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
