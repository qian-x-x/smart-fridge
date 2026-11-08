param([string]$BaseUrl = 'http://127.0.0.1:8080')

$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
function Request([string]$Label, [string]$Method, [string]$Path, $Session, $Body, [int]$Expected = 200, [switch]$Raw,
    [string]$ContentType = 'application/json; charset=utf-8') {
    $params = @{Method=$Method; Uri="$BaseUrl$Path"; SkipHttpErrorCheck=$true; TimeoutSec=20}
    if ($Method -in 'POST','PUT','PATCH') { $params.ContentType=$ContentType }
    if ($Session) { $params.Headers = @{Authorization="Bearer $($Session.accessToken)"} }
    if ($null -ne $Body) {
        $params.ContentType=$ContentType
        $json = if ($Raw) { [string]$Body } else { $Body | ConvertTo-Json -Depth 10 -Compress }
        $params.Body=[Text.Encoding]::UTF8.GetBytes($json)
    }
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $response=Invoke-WebRequest @params
    $payload=$null
    if ($response.Content) {
        $responseText=if($response.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($response.Content)}else{$response.Content}
        try { $payload=$responseText | ConvertFrom-Json } catch {}
    }
    $ok=([int]$response.StatusCode -eq $Expected)
    if ($Expected -in 200,201 -and $Path.StartsWith('/api/')) { $ok=$ok -and $payload.code -eq 'OK' }
    if ($Expected -ge 400) { $ok=$ok -and $payload.code -and $payload.message }
    $checks.Add([pscustomobject]@{
        check=$Label;method=$Method;path=$Path;expected=$Expected;status=[int]$response.StatusCode;
        code=$payload.code;message=if($Expected -ge 400){$payload.message}else{$null};
        passed=[bool]$ok;elapsedMs=$timer.ElapsedMilliseconds
    })
    return $payload.data
}
function Assert([bool]$Condition,[string]$Label) {
    $checks.Add([pscustomobject]@{check=$Label;passed=$Condition})
}
function Copy-Body($Body, $Changes) {
    $copy=@{}; foreach($key in $Body.Keys){$copy[$key]=$Body[$key]}
    foreach($key in $Changes.Keys){$copy[$key]=$Changes[$key]}; return $copy
}

$stamp=Get-Date -Format 'yyyyMMddHHmmssfff'
$register=@{username="audit_a_$stamp";displayName='接口审查A';password='AuditTest2026'}
$owner=Request 'register owner' POST '/api/v1/auth/register' $null $register 201
$member=Request 'register member' POST '/api/v1/auth/register' $null @{username="audit_b_$stamp";displayName='接口审查B';password='AuditTest2026'} 201
$stranger=Request 'register stranger' POST '/api/v1/auth/register' $null @{username="audit_c_$stamp";displayName='隔离审查';password='AuditTest2026'} 201
if(!$owner -or !$member -or !$stranger){throw 'Cannot establish isolated audit fixtures'}
$phone='199'+$stamp.Substring($stamp.Length-8)
$phoneSession=Request 'phone-only registration' POST '/api/v1/auth/register' $null @{phone=$phone;displayName='手机账号审查';password='AuditTest2026'} 201
$null=Request 'phone login' POST '/api/v1/auth/login' $null @{identifier=$phone;password='AuditTest2026'}
$null=Request 'phone account passes gateway with nullable username' GET '/api/v1/families' $phoneSession $null
foreach($port in 8080..8085) {
    $response=Invoke-WebRequest "http://127.0.0.1:$port/actuator/health" -SkipHttpErrorCheck -TimeoutSec 10
    $healthText=if($response.Content -is [byte[]]){[Text.Encoding]::UTF8.GetString($response.Content)}else{$response.Content}
    $health=$healthText | ConvertFrom-Json
    $checks.Add([pscustomobject]@{check="health $port";status=[int]$response.StatusCode;
        passed=([int]$response.StatusCode -eq 200 -and $health.status -eq 'UP')})
}
foreach($route in @('fridges','recipes','products','orders')) {
    $null=Request "$route ping" GET "/api/v1/$route/ping" $owner $null
    $null=Request "$route ping requires token" GET "/api/v1/$route/ping" $null $null 401
}
$null=Request 'duplicate registration' POST '/api/v1/auth/register' $null $register 409
$null=Request 'invalid registration' POST '/api/v1/auth/register' $null @{username='bad user';displayName='';password='short'} 400
$null=Request 'malformed auth JSON' POST '/api/v1/auth/register' $null '{' 400 -Raw
$null=Request 'UTF8 password over storage limit' POST '/api/v1/auth/register' $null @{username="utf8_$stamp";displayName='密码校验';password=('密'*25)} 400
$null=Request 'login UTF8 password limit' POST '/api/v1/auth/login' $null @{identifier=$register.username;password=('密'*25)} 400
$null=Request 'wrong login password' POST '/api/v1/auth/login' $null @{identifier=$register.username;password='WrongPassword2026'} 401
$login=Request 'valid login' POST '/api/v1/auth/login' $null @{identifier=$register.username;password=$register.password}
$null=Request 'introspect access token' POST '/api/v1/auth/introspect' $owner $null
$null=Request 'introspect missing token' POST '/api/v1/auth/introspect' $null $null 401
$null=Request 'refresh rejects access token' POST '/api/v1/auth/refresh' $null @{refreshToken=$owner.accessToken} 401
$null=Request 'refresh rejects malformed token' POST '/api/v1/auth/refresh' $null @{refreshToken='invalid'} 401
$null=Request 'missing access token' GET '/api/v1/families' $null $null 401
$null=Request 'invalid access token' GET '/api/v1/recipes' @{accessToken='invalid'} $null 401
$null=Request 'refresh token cannot access API' GET '/api/v1/recipes' @{accessToken=$owner.refreshToken} $null 401

$family=Request 'create family' POST '/api/v1/families' $owner @{name="接口审查_$stamp"} 201
$null=Request 'list families' GET '/api/v1/families' $owner $null
$null=Request 'get family' GET "/api/v1/families/$($family.id)" $owner $null
$null=Request 'family isolation' GET "/api/v1/families/$($family.id)" $stranger $null 404
$null=Request 'blank family name' POST '/api/v1/families' $owner @{name=' '} 400
$null=Request 'long family name' POST '/api/v1/families' $owner @{name=('家'*61)} 400
$null=Request 'invalid family path type' GET '/api/v1/families/not-a-number' $owner $null 400
$null=Request 'unknown family endpoint' GET '/api/v1/families/1/unknown' $owner $null 404
$null=Request 'unsupported method' PUT '/api/v1/families' $owner @{name='unsupported'} 405
$null=Request 'invalid invitation' POST '/api/v1/families/join' $member @{inviteCode='bad'} 400
$null=Request 'unknown invitation' POST '/api/v1/families/join' $member @{inviteCode='ZZZZZZZZ'} 404
$joined=Request 'join viewer' POST '/api/v1/families/join' $member @{inviteCode=$family.inviteCode}
Assert ($joined.currentUserRole -eq 'VIEWER') 'join defaults to VIEWER'
$null=Request 'repeat join' POST '/api/v1/families/join' $member @{inviteCode=$family.inviteCode}
$members=Request 'list members' GET "/api/v1/families/$($family.id)/members" $owner $null
Assert ($members.Count -eq 2) 'repeat join remains idempotent'
$null=Request 'viewer cannot govern' PATCH "/api/v1/families/$($family.id)/members/$($owner.user.id)" $member @{role='EDITOR'} 403
$null=Request 'invalid role' PATCH "/api/v1/families/$($family.id)/members/$($member.user.id)" $owner @{role='ADMIN'} 400

$null=Request 'fridge absent' GET "/api/v1/fridges?familyId=$($family.id)" $owner $null 404
$null=Request 'missing family query' GET '/api/v1/fridges' $owner $null 400
$null=Request 'invalid family query' GET '/api/v1/fridges?familyId=abc' $owner $null 400
$null=Request 'invalid fridge payload' POST '/api/v1/fridges' $owner @{familyId=0;name=''} 400
$null=Request 'viewer cannot create fridge' POST '/api/v1/fridges' $member @{familyId=$family.id;name='viewer'} 403
$fridge=Request 'create fridge' POST '/api/v1/fridges' $owner @{familyId=$family.id;name='接口审查冰箱'} 201
if(!$fridge){throw 'Cannot establish fridge fixture'}
Assert ($fridge.zones.Count -eq 4) 'four default zones'
$null=Request 'get fridge by family' GET "/api/v1/fridges?familyId=$($family.id)" $owner $null
$null=Request 'get fridge by id' GET "/api/v1/fridges/$($fridge.id)" $owner $null
$null=Request 'fridge isolation' GET "/api/v1/fridges/$($fridge.id)" $stranger $null 404
$null=Request 'duplicate fridge' POST '/api/v1/fridges' $owner @{familyId=$family.id;name='duplicate'} 409
$fresh=$fridge.zones | Where-Object code -eq 'FRESH'
if(!$fresh){$fresh=$fridge.zones[0]}
$other=$fridge.zones | Where-Object id -ne $fresh.id | Select-Object -First 1
$foodBody=@{fridgeId=$fridge.id;zoneId=$fresh.id;containerId=$fresh.containers[0].id;name='接口审查牛奶';category='蛋奶';quantity=2;unit='盒';productionDate=(Get-Date).ToString('yyyy-MM-dd');expiresOn=(Get-Date).AddDays(2).ToString('yyyy-MM-dd');tags=@('早餐','高蛋白')}
$null=Request 'viewer cannot add food' POST '/api/v1/foods' $member $foodBody 403
$food=Request 'owner adds food' POST '/api/v1/foods' $owner $foodBody 201
Assert ($food.quantity -eq 2 -and $food.zoneId -eq $fresh.id -and $food.version -eq 0) 'food creation response fields'
foreach($case in @(
    @{label='blank name';change=@{name=' '}},
    @{label='long name';change=@{name=('菜'*81)}},
    @{label='zero quantity';change=@{quantity=0}},
    @{label='negative quantity';change=@{quantity=-1}},
    @{label='quantity below storage precision';change=@{quantity=0.0001}},
    @{label='quantity excess scale';change=@{quantity=1.2345}},
    @{label='quantity overflow';change=@{quantity=1000000000}},
    @{label='invalid date';change=@{expiresOn='2026-02-30'}},
    @{label='blank category';change=@{category=''}},
    @{label='null quantity';change=@{quantity=$null}},
    @{label='long unit';change=@{unit=('盒'*21)}},
    @{label='too many tags';change=@{tags=@(1..21 | ForEach-Object {"t$_"})}},
    @{label='tags overflow storage';change=@{tags=@(1..20 | ForEach-Object { $_.ToString().PadLeft(30,'a') })}},
    @{label='tag contains delimiter';change=@{tags=@('早餐,高蛋白')}}
)){
    $null=Request "invalid food: $($case.label)" POST '/api/v1/foods' $owner (Copy-Body $foodBody $case.change) 400
}
$null=Request 'malformed food JSON' POST '/api/v1/foods' $owner '{' 400 -Raw
$null=Request 'missing food body' POST '/api/v1/foods' $owner $null 400
$null=Request 'unsupported food media type' POST '/api/v1/foods' $owner '{}' 415 -Raw -ContentType 'text/plain'
$null=Request 'foreign zone' POST '/api/v1/foods' $owner (Copy-Body $foodBody @{zoneId=999999999}) 409
$null=Request 'container in other zone' POST '/api/v1/foods' $owner (Copy-Body $foodBody @{containerId=$other.containers[0].id}) 409
$null=Request 'date order conflict' POST '/api/v1/foods' $owner (Copy-Body $foodBody @{expiresOn='2020-01-01'}) 409
$null=Request 'get food' GET "/api/v1/foods/$($food.id)" $owner $null
$null=Request 'get food isolation' GET "/api/v1/foods/$($food.id)" $stranger $null 404
$null=Request 'missing fridge query' GET '/api/v1/foods' $owner $null 400
$null=Request 'invalid food path' GET '/api/v1/foods/abc' $owner $null 400
$foods=Request 'search foods' GET "/api/v1/foods?fridgeId=$($fridge.id)" $owner $null
Assert (@($foods).Count -ge 1) 'search returns created record'
$filtered=Request 'combined search' GET "/api/v1/foods?fridgeId=$($fridge.id)&tags=$([uri]::EscapeDataString('早餐'))&tags=$([uri]::EscapeDataString('高蛋白'))&sort=NAME_ASC&expiryState=EXPIRING" $owner $null
Assert (@($filtered).Count -ge 1) 'combined search response'
$null=Request 'invalid sort' GET "/api/v1/foods?fridgeId=$($fridge.id)&sort=INVALID" $owner $null 400
$null=Request 'invalid date range' GET "/api/v1/foods?fridgeId=$($fridge.id)&expiresFrom=2027-01-01&expiresTo=2026-01-01" $owner $null 400
$null=Request 'viewer cannot consume' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=1;version=0} 403
$null=Request 'promote member' PATCH "/api/v1/families/$($family.id)/members/$($member.user.id)" $owner @{role='EDITOR'}
$null=Request 'excess consume' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=3;version=0} 409
$null=Request 'zero consume' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=0;version=0} 400
$null=Request 'fractional precision consume' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=1.2345;version=0} 400
$consumed=Request 'editor consumes' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=1;version=0}
Assert ($consumed.quantity -eq 1 -and $consumed.version -eq 1) 'consume response quantity and version'
$null=Request 'stale consume conflict' POST "/api/v1/foods/$($food.id)/consume" $member @{quantity=1;version=0} 409
$moved=Request 'move food' POST "/api/v1/foods/$($food.id)/move" $member @{zoneId=$other.id;containerId=$other.containers[0].id;version=$consumed.version}
Assert ($moved.zoneId -eq $other.id -and $moved.version -eq 2) 'move response location and version'
$updated=Request 'edit food' PUT "/api/v1/foods/$($food.id)" $member (Copy-Body $foodBody @{zoneId=$other.id;containerId=$other.containers[0].id;quantity=4;name='已编辑牛奶';version=$moved.version})
Assert ($updated.quantity -eq 4 -and $updated.version -eq 3) 'edit response fields'
$null=Request 'stale delete conflict' DELETE "/api/v1/foods/$($food.id)?version=0" $owner $null 409
$null=Request 'missing delete version' DELETE "/api/v1/foods/$($food.id)" $owner $null 400
$null=Request 'soft delete' DELETE "/api/v1/foods/$($food.id)?version=$($updated.version)" $owner $null 204
$null=Request 'deleted food absent' GET "/api/v1/foods/$($food.id)" $owner $null 404

$recipes=Request 'recipe catalogue' GET '/api/v1/recipes' $owner $null
Assert (@($recipes).Count -gt 0) 'catalogue contains recipes'
$recipe=Request 'recipe detail' GET "/api/v1/recipes/$($recipes[0].id)" $owner $null
Assert ($recipe.ingredients.Count -gt 0 -and $recipe.steps.Count -gt 0) 'recipe detail contract'
$null=Request 'recipe missing' GET '/api/v1/recipes/999999999' $owner $null 404
$null=Request 'recipe path type' GET '/api/v1/recipes/abc' $owner $null 400
$null=Request 'recipe unknown endpoint' GET '/api/v1/recipes/1/unknown' $owner $null 404
$null=Request 'transfer owner' POST "/api/v1/families/$($family.id)/transfer-owner" $owner @{targetUserId=$member.user.id}
$null=Request 'old owner cannot govern' PATCH "/api/v1/families/$($family.id)/members/$($member.user.id)" $owner @{role='VIEWER'} 403
$null=Request 'remove old owner' DELETE "/api/v1/families/$($family.id)/members/$($owner.user.id)" $member $null 204
$null=Request 'removed member denied' GET "/api/v1/fridges/$($fridge.id)" $owner $null 404

$rotated=Request 'refresh rotation' POST '/api/v1/auth/refresh' $null @{refreshToken=$login.refreshToken}
$null=Request 'logout rejects token from another user' POST '/api/v1/auth/logout' $rotated @{refreshToken=$member.refreshToken} 400
$null=Request 'mismatched logout did not revoke current session' POST '/api/v1/auth/introspect' $rotated $null
$null=Request 'rotated old refresh rejected' POST '/api/v1/auth/refresh' $null @{refreshToken=$login.refreshToken} 401
$null=Request 'logout' POST '/api/v1/auth/logout' $rotated @{refreshToken=$rotated.refreshToken}
$null=Request 'logout revokes introspection' POST '/api/v1/auth/introspect' $rotated $null 401
$null=Request 'logout revokes family access' GET '/api/v1/families' $rotated $null 401
$null=Request 'logout revokes recipe access' GET '/api/v1/recipes' $rotated $null 401
$null=Request 'logout revokes refresh' POST '/api/v1/auth/refresh' $null @{refreshToken=$rotated.refreshToken} 401
$passed=@($checks | Where-Object passed).Count
$failed=$checks.Count-$passed
[pscustomobject]@{checkedAt=(Get-Date -Format o);baseUrl=$BaseUrl;familyId=$family.id;fridgeId=$fridge.id;total=$checks.Count;passed=$passed;failed=$failed;checks=$checks} | ConvertTo-Json -Depth 6
if($failed){exit 1}
