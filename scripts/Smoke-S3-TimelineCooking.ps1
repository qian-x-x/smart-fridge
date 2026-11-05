#Requires -Version 7.0
<#
.SYNOPSIS
    S3 真实链路联调：时间线、撤销/恢复、做饭扣减、权限与登出撤销。

.DESCRIPTION
    通过 Gateway 访问真实的 auth-family / fridge / recipe 服务与 MySQL、Redis。
    每个断言独立记录，失败不会中断后续检查，最终写出 JSON 结果。
    脚本会创建独立的验收账号与家庭，不修改既有数据。
#>
[CmdletBinding()]
param(
    [string]$Gateway = 'http://127.0.0.1:8080',
    [string]$OutFile = 'docs/reviews/evidence/2026-11-06-s3/api-acceptance.json'
)

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
$stamp = Get-Date -Format 'MMddHHmmss'

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
    $payload = @{
        username    = $username
        displayName = $Display
        password    = 'Accept2026!'
    }
    $result = Invoke-Call -Method POST -Path '/api/v1/auth/register' -Body $payload
    [pscustomobject]@{
        Username = $username
        Result   = $result
        Token    = $result.Body.data.accessToken
        Refresh  = $result.Body.data.refreshToken
        Id       = $result.Body.data.user.id
    }
}

Write-Output "== S3 acceptance via $Gateway (run $stamp) =="

# 1. 账号与家庭
$owner = New-Account -Prefix 's3own' -Display '验收拥有者'
Check 'register-owner' ($owner.Result.Status -eq 201 -and $owner.Token) "status=$($owner.Result.Status)"

$member = New-Account -Prefix 's3mem' -Display '验收成员'
Check 'register-member' ($member.Result.Status -eq 201 -and $member.Token) "status=$($member.Result.Status)"

$family = Invoke-Call -Method POST -Path '/api/v1/families' -Headers (Auth $owner.Token) -Body @{ name = "S3 验收家庭 $stamp" }
$familyId = $family.Body.data.id
$inviteCode = $family.Body.data.inviteCode
Check 'create-family' (((($family.Status -eq 200) -or ($family.Status -eq 201))) -and ($familyId -gt 0)) "status=$($family.Status) familyId=$familyId"
Check 'invite-code-format' ($inviteCode -match '^[A-Za-z0-9]{8}$') "inviteCode=$inviteCode"

$join = Invoke-Call -Method POST -Path '/api/v1/families/join' -Headers (Auth $member.Token) -Body @{ inviteCode = $inviteCode }
Check 'member-joins-as-viewer' ($join.Status -eq 200 -and $join.Body.data.currentUserRole -eq 'VIEWER') "status=$($join.Status) role=$($join.Body.data.currentUserRole)"

# 2. 冰箱与食材
$fridge = Invoke-Call -Method POST -Path '/api/v1/fridges' -Headers (Auth $owner.Token) -Body @{ familyId = $familyId; name = "S3 验收冰箱 $stamp" }
$fridgeId = $fridge.Body.data.id
$zoneId = $fridge.Body.data.zones[0].id
$containerId = $fridge.Body.data.zones[0].containers[0].id
Check 'create-fridge-with-zones' ($fridge.Status -eq 201 -and $fridge.Body.data.zones.Count -eq 4) "status=$($fridge.Status) zones=$($fridge.Body.data.zones.Count)"

$today = (Get-Date).Date
$production = $today.AddDays(-2).ToString('yyyy-MM-dd')
$expires = $today.AddDays(5).ToString('yyyy-MM-dd')

function Add-Food {
    param([string]$Name, [double]$Quantity, [string]$Unit, [string]$Category)
    $payload = @{
        fridgeId       = $fridgeId
        zoneId         = $zoneId
        containerId    = $containerId
        name           = $Name
        category       = $Category
        quantity       = $Quantity
        unit           = $Unit
        productionDate = $production
        expiresOn      = $expires
        tags           = @('验收')
    }
    Invoke-Call -Method POST -Path '/api/v1/foods' -Headers (Auth $owner.Token) -Body $payload
}

$milk = Add-Food -Name "验收牛奶 $stamp" -Quantity 4 -Unit '盒' -Category '奶制品'
$egg = Add-Food -Name "验收鸡蛋 $stamp" -Quantity 6 -Unit '个' -Category '蛋类'
$milkId = $milk.Body.data.id
$eggId = $egg.Body.data.id
Check 'add-two-foods' ($milk.Status -eq 201 -and $egg.Status -eq 201) "milk=$($milk.Status) egg=$($egg.Status)"

# 3. 使用与时间线
$consume = Invoke-Call -Method POST -Path "/api/v1/foods/$milkId/consume" -Headers (Auth $owner.Token) -Body @{ quantity = 1; version = 0 }
Check 'consume-food' ($consume.Status -eq 200 -and $consume.Body.data.quantity -eq 3) "status=$($consume.Status) quantity=$($consume.Body.data.quantity)"

$timeline = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/operations?limit=10" -Headers (Auth $owner.Token)
$first = $timeline.Body.data[0]
Check 'timeline-lists-consume' ($timeline.Status -eq 200 -and $first.action -eq 'CONSUME' -and $first.undoable -eq $true) "status=$($timeline.Status) first=$($first.action) undoable=$($first.undoable)"
$consumeOperationId = $first.id

# 4. 撤销与恢复
$undo = Invoke-Call -Method POST -Path "/api/v1/foods/$milkId/operations/$consumeOperationId/undo" -Headers (Auth $owner.Token)
Check 'undo-restores-quantity' ($undo.Status -eq 200 -and $undo.Body.data.quantity -eq 4) "status=$($undo.Status) quantity=$($undo.Body.data.quantity)"

$timelineAfterUndo = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/operations?limit=3" -Headers (Auth $owner.Token)
$undoEntry = $timelineAfterUndo.Body.data[0]
$originalEntry = $timelineAfterUndo.Body.data[1]
Check 'undo-writes-history' ($undoEntry.action -eq 'UNDO' -and $undoEntry.originalOperationId -eq $consumeOperationId) "action=$($undoEntry.action) original=$($undoEntry.originalOperationId)"
Check 'original-marked-undone' ($originalEntry.undone -eq $true -and $originalEntry.undoable -eq $false) "undone=$($originalEntry.undone) undoable=$($originalEntry.undoable)"

$secondUndo = Invoke-Call -Method POST -Path "/api/v1/foods/$milkId/operations/$consumeOperationId/undo" -Headers (Auth $owner.Token)
Check 'undo-twice-conflicts' ($secondUndo.Status -eq 409) "status=$($secondUndo.Status) code=$($secondUndo.Body.code)"

$restore = Invoke-Call -Method POST -Path "/api/v1/foods/$milkId/operations/$consumeOperationId/restore" -Headers (Auth $owner.Token)
Check 'restore-reapplies' ($restore.Status -eq 200 -and $restore.Body.data.quantity -eq 3) "status=$($restore.Status) quantity=$($restore.Body.data.quantity)"

# 5. 做饭扣减与幂等
$cookRequestId = "cook-$stamp-01"
$milkCurrent = Invoke-Call -Method GET -Path "/api/v1/foods/$milkId" -Headers (Auth $owner.Token)
$eggCurrent = Invoke-Call -Method GET -Path "/api/v1/foods/$eggId" -Headers (Auth $owner.Token)
$cookBody = @{
    recipeId   = 1
    recipeName = '番茄滑蛋'
    servings   = 2
    requestId  = $cookRequestId
    note       = 'S3 验收'
    items      = @(
        @{ foodItemId = $milkId; quantity = 1; version = $milkCurrent.Body.data.version },
        @{ foodItemId = $eggId; quantity = 2; version = $eggCurrent.Body.data.version }
    )
}
$cook = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/cook-records" -Headers (Auth $owner.Token) -Body $cookBody
$cookRecordId = $cook.Body.data.id
Check 'cook-created' ($cook.Status -eq 201 -and $cook.Body.data.items.Count -eq 2) "status=$($cook.Status) record=$cookRecordId items=$($cook.Body.data.items.Count)"

$milkAfter = Invoke-Call -Method GET -Path "/api/v1/foods/$milkId" -Headers (Auth $owner.Token)
$eggAfter = Invoke-Call -Method GET -Path "/api/v1/foods/$eggId" -Headers (Auth $owner.Token)
Check 'cook-deducts-both' ($milkAfter.Body.data.quantity -eq 2 -and $eggAfter.Body.data.quantity -eq 4) "milk=$($milkAfter.Body.data.quantity) egg=$($eggAfter.Body.data.quantity)"

$replay = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/cook-records" -Headers (Auth $owner.Token) -Body $cookBody
$milkReplay = Invoke-Call -Method GET -Path "/api/v1/foods/$milkId" -Headers (Auth $owner.Token)
Check 'cook-replay-is-idempotent' ($replay.Status -eq 200 -and $replay.Body.data.id -eq $cookRecordId) "status=$($replay.Status) record=$($replay.Body.data.id)"
Check 'replay-does-not-deduct' ($milkReplay.Body.data.quantity -eq 2) "milk=$($milkReplay.Body.data.quantity)"

$records = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/cook-records" -Headers (Auth $owner.Token)
Check 'cook-records-listed' ($records.Status -eq 200 -and $records.Body.data.Count -eq 1 -and $records.Body.data[0].items.Count -eq 2) "count=$($records.Body.data.Count) items=$($records.Body.data[0].items.Count)"

$cookTimeline = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/operations?limit=5" -Headers (Auth $owner.Token)
$cookActions = @($cookTimeline.Body.data | Where-Object { $_.action -eq 'COOK' })
Check 'cook-writes-operation' ($cookActions.Count -eq 2) "cookOperations=$($cookActions.Count)"

# 6. 只读权限
$viewerTimeline = Invoke-Call -Method GET -Path "/api/v1/fridges/$fridgeId/operations" -Headers (Auth $member.Token)
Check 'viewer-reads-timeline' ($viewerTimeline.Status -eq 200) "status=$($viewerTimeline.Status)"

$viewerUndo = Invoke-Call -Method POST -Path "/api/v1/foods/$milkId/operations/$consumeOperationId/undo" -Headers (Auth $member.Token)
Check 'viewer-cannot-undo' ($viewerUndo.Status -eq 403) "status=$($viewerUndo.Status) code=$($viewerUndo.Body.code)"

$viewerCook = Invoke-Call -Method POST -Path "/api/v1/fridges/$fridgeId/cook-records" -Headers (Auth $member.Token) -Body $cookBody
Check 'viewer-cannot-cook' ($viewerCook.Status -eq 403) "status=$($viewerCook.Status) code=$($viewerCook.Body.code)"

# 7. 参数与跨家庭隔离
$staleUndo = Invoke-Call -Method POST -Path "/api/v1/foods/$eggId/operations/$consumeOperationId/undo?version=99" -Headers (Auth $owner.Token)
Check 'undo-rejects-foreign-operation' ($staleUndo.Status -eq 404) "status=$($staleUndo.Status) code=$($staleUndo.Body.code)"

$outsider = New-Account -Prefix 's3out' -Display '验收外部账号'
$otherFamily = Invoke-Call -Method POST -Path '/api/v1/families' -Headers (Auth $outsider.Token) -Body @{ name = "S3 外部家庭 $stamp" }
$otherFridge = Invoke-Call -Method POST -Path '/api/v1/fridges' -Headers (Auth $outsider.Token) -Body @{ familyId = $otherFamily.Body.data.id; name = '外部冰箱' }
$crossTimeline = Invoke-Call -Method GET -Path "/api/v1/fridges/$($otherFridge.Body.data.id)/operations" -Headers (Auth $owner.Token)
Check 'cross-family-timeline-hidden' ($crossTimeline.Status -eq 404) "status=$($crossTimeline.Status) code=$($crossTimeline.Body.code)"

$missingFridge = Invoke-Call -Method GET -Path '/api/v1/fridges/999999/operations' -Headers (Auth $owner.Token)
Check 'unknown-fridge-not-found' ($missingFridge.Status -eq 404) "status=$($missingFridge.Status)"

# 8. 网关契约与登出撤销
$recipes = Invoke-Call -Method GET -Path '/api/v1/recipes' -Headers (Auth $owner.Token)
Check 'gateway-routes-recipe' ($recipes.Status -eq 200 -and $recipes.Body.data.Count -ge 6) "status=$($recipes.Status) recipes=$($recipes.Body.data.Count)"

$logout = Invoke-Call -Method POST -Path '/api/v1/auth/logout' -Headers (Auth $owner.Token) -Body @{ refreshToken = $owner.Refresh }
Check 'logout-accepted' ($logout.Status -eq 200) "status=$($logout.Status)"

$afterLogout = Invoke-Call -Method GET -Path '/api/v1/families' -Headers (Auth $owner.Token)
Check 'revoked-token-rejected' ($afterLogout.Status -eq 401) "status=$($afterLogout.Status) code=$($afterLogout.Body.code)"

$failed = @($checks | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
    runAt    = (Get-Date).ToString('o')
    gateway  = $Gateway
    total    = $checks.Count
    passed   = $checks.Count - $failed.Count
    failed   = $failed.Count
    familyId = $familyId
    fridgeId = $fridgeId
    checks   = $checks
}

$directory = Split-Path -Parent $OutFile
if ($directory -and -not (Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8

Write-Output ""
Write-Output ("== {0}/{1} assertions passed, {2} failed ==" -f $summary.passed, $summary.total, $summary.failed)
Write-Output "result: $OutFile"
if ($failed.Count -gt 0) { exit 1 }
