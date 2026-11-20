param([string]$BaseUrl = 'http://127.0.0.1:8080')

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
function Request([string]$Label, [string]$Method, [string]$Path, $Session, $Body, [int]$Expected = 200) {
    $params = @{ Method=$Method; Uri="$BaseUrl/api/v1$Path"; SkipHttpErrorCheck=$true }
    if ($Session) { $params.Headers = @{Authorization="Bearer $($Session.accessToken)"} }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
    }
    $response = Invoke-WebRequest @params
    if ([int]$response.StatusCode -ne $Expected) {
        throw "$Label expected $Expected, got $($response.StatusCode): $($response.Content)"
    }
    $checks.Add([pscustomobject]@{check=$Label; status=[int]$response.StatusCode; passed=$true})
    if ($response.Content) { return ($response.Content | ConvertFrom-Json).data }
}
function Assert([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "Assertion failed: $Label" }
    $checks.Add([pscustomobject]@{check=$Label; passed=$true})
}

$stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
$owner = Request 'register owner' POST '/auth/register' $null @{username="ws_a_$stamp"; password='SmokeTest2026'; displayName='工作区验收A'} 201
$member = Request 'register member' POST '/auth/register' $null @{username="ws_b_$stamp"; password='SmokeTest2026'; displayName='工作区验收B'} 201
$shared = Request 'create shared family' POST '/families' $owner @{name="工作区共享_$stamp"} 201
$private = Request 'create private family' POST '/families' $member @{name="工作区独立_$stamp"} 201
$null = Request 'family isolation before join' GET "/families/$($shared.id)" $member $null 404
$null = Request 'no fridge yet' GET "/fridges?familyId=$($shared.id)" $owner $null 404
$joined = Request 'join as viewer' POST '/families/join' $member @{inviteCode=$shared.inviteCode.ToLowerInvariant()}
Assert ($joined.currentUserRole -eq 'VIEWER') 'joined role is VIEWER'
$null = Request 'repeat join is idempotent' POST '/families/join' $member @{inviteCode=$shared.inviteCode}
$members = Request 'list members' GET "/families/$($shared.id)/members" $owner $null
Assert ($members.Count -eq 2) 'repeat join does not duplicate members'
$null = Request 'viewer cannot create fridge' POST '/fridges' $member @{familyId=$shared.id;name='禁止创建'} 403
$fridge = Request 'owner creates fridge' POST '/fridges' $owner @{familyId=$shared.id;name='工作区验收冰箱'} 201
Assert (($fridge.zones.code -join ',') -eq 'FRESH,VARIABLE,FREEZER') 'default fridge has three zones'
$null = Request 'duplicate fridge rejected' POST '/fridges' $owner @{familyId=$shared.id;name='重复冰箱'} 409
$zone = $fridge.zones[0]
$foodBody = @{fridgeId=$fridge.id;zoneId=$zone.id;containerId=$zone.containers[0].id;name='验收牛奶';category='蛋奶';quantity=2;unit='盒';productionDate=(Get-Date).AddDays(-1).ToString('yyyy-MM-dd');expiresOn=(Get-Date).AddDays(2).ToString('yyyy-MM-dd');tags=@('早餐')}
$null = Request 'viewer cannot add food' POST '/foods' $member $foodBody 403
$null = Request 'viewer cannot govern' PATCH "/families/$($shared.id)/members/$($owner.user.id)" $member @{role='VIEWER'} 403
$null = Request 'promote editor' PATCH "/families/$($shared.id)/members/$($member.user.id)" $owner @{role='EDITOR'}
$food = Request 'editor adds food with same token' POST '/foods' $member $foodBody 201
$null = Request 'editor still cannot configure fridge' POST '/fridges' $member @{familyId=$shared.id;name='无权限'} 403
$null = Request 'transfer ownership' POST "/families/$($shared.id)/transfer-owner" $owner @{targetUserId=$member.user.id}
$after = Request 'verify ownership' GET "/families/$($shared.id)" $member $null
Assert ($after.ownerUserId -eq $member.user.id -and $after.currentUserRole -eq 'OWNER') 'new owner is consistent'
$null = Request 'old owner cannot govern' PATCH "/families/$($shared.id)/members/$($member.user.id)" $owner @{role='VIEWER'} 403
$null = Request 'new owner demotes old owner' PATCH "/families/$($shared.id)/members/$($owner.user.id)" $member @{role='VIEWER'}
$null = Request 'demotion affects existing token immediately' POST "/foods/$($food.id)/consume" $owner @{quantity=1;version=$food.version} 403
$null = Request 'other family remains isolated' GET "/fridges?familyId=$($private.id)" $owner $null 404
$null = Request 'new owner removes member' DELETE "/families/$($shared.id)/members/$($owner.user.id)" $member $null 204
$null = Request 'removed member loses fridge access' GET "/fridges/$($fridge.id)" $owner $null 404
$null = Request 'recipes route works' GET '/recipes' $member $null
[pscustomobject]@{baseUrl=$BaseUrl; checkedAt=(Get-Date -Format o); familyId=$shared.id; fridgeId=$fridge.id; passed=$checks.Count; checks=$checks} | ConvertTo-Json -Depth 6
