param([string]$BaseUrl = 'http://127.0.0.1:8080')
$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
function Call([string]$Label, [string]$Method, [string]$Path, $Body = $null, [int]$Expected = 200) {
    $options = @{Method=$Method; Uri="$BaseUrl/api/v1$Path"; SkipHttpErrorCheck=$true}
    if ($script:filterSession) { $options.Headers=@{Authorization="Bearer $($script:filterSession.accessToken)"} }
    if ($null -ne $Body) {
        $options.ContentType='application/json; charset=utf-8'
        $options.Body=[Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 8))
    }
    $response=Invoke-WebRequest @options
    if ([int]$response.StatusCode -ne $Expected) { throw "$Label expected $Expected, got $($response.StatusCode): $($response.Content)" }
    $checks.Add(@{check=$Label; passed=$true; status=[int]$response.StatusCode})
    if ($response.Content) { return ($response.Content | ConvertFrom-Json).data }
}
function Check([bool]$Condition, [string]$Label) {
    if (-not $Condition) { throw "Failed: $Label" }
    $checks.Add(@{check=$Label; passed=$true})
}
$stamp=Get-Date -Format 'yyyyMMddHHmmssfff'
$username="filter_$stamp"
$script:filterSession=$null
$script:filterSession=Call 'register fixture' POST '/auth/register' @{username=$username;password='FilterTest2026';displayName='筛选验收用户'} 201
$family=Call 'create fixture family' POST '/families' @{name="筛选验收家庭_$stamp"} 201
$fridge=Call 'create fixture fridge' POST '/fridges' @{familyId=$family.id;name='组合筛选验收冰箱'} 201
$foods=@()
foreach ($item in @(
    @{name='筛选牛奶'; category='蛋奶'; days=2; tags=@('早餐','高蛋白');zone=0},
    @{name='筛选酸奶'; category='蛋奶'; days=5; tags=@('早餐');zone=0},
    @{name='筛选过期奶'; category='蛋奶'; days=-1; tags=@('早餐');zone=0},
    @{name='筛选蔬菜'; category='蔬菜'; days=0; tags=@('晚餐');zone=1},
    @{name='100%_!牛奶'; category='蛋奶'; days=3; tags=@('特殊%_!');zone=0}
)) {
    $zone=$fridge.zones[$item.zone]
    $foods+=Call "seed $($item.name)" POST '/foods' @{
        fridgeId=$fridge.id; zoneId=$zone.id; containerId=$zone.containers[0].id;
        name=$item.name;category=$item.category;quantity=2;unit='份';tags=$item.tags;
        productionDate=(Get-Date).AddDays(-10).ToString('yyyy-MM-dd');expiresOn=(Get-Date).AddDays($item.days).ToString('yyyy-MM-dd')
    } 201
}
$prefix="/foods?fridgeId=$($fridge.id)"
$url="$prefix&query=$([Uri]::EscapeDataString('奶'))&category=$([Uri]::EscapeDataString('蛋奶'))&tags=$([Uri]::EscapeDataString('早餐'))&tags=$([Uri]::EscapeDataString('高蛋白'))&zoneId=$($fridge.zones[0].id)&expiryState=EXPIRING&sort=EXPIRES_ASC"
$result=@(Call 'combined MySQL filters' GET $url)
Check ($result.Count -eq 1 -and $result[0].name -eq '筛选牛奶') 'all conditions and all tags matched'
$result=@(Call 'expired filter' GET "$prefix&expiryState=EXPIRED")
Check ($result.Count -eq 1 -and $result[0].remainingDays -eq -1) 'expired boundary'
$result=@(Call 'expiring filter' GET "$prefix&expiryState=EXPIRING")
Check ($result.Count -eq 3) 'today and day three included'
$result=@(Call 'fresh filter' GET "$prefix&expiryState=FRESH")
Check ($result.Count -eq 1 -and $result[0].name -eq '筛选酸奶') 'fresh excludes day three'
$result=@(Call 'literal wildcard query' GET "$prefix&query=$([Uri]::EscapeDataString('%_!'))&tags=$([Uri]::EscapeDataString('特殊%_!'))")
Check ($result.Count -eq 1 -and $result[0].name -eq '100%_!牛奶') 'MySQL LIKE escapes special characters'
$result=@(Call 'descending expiration' GET "$prefix&sort=EXPIRES_DESC")
Check ($result[0].name -eq '筛选酸奶') 'descending sort applied'
$day=(Get-Date).AddDays(2).ToString('yyyy-MM-dd')
$result=@(Call 'inclusive dates' GET "$prefix&expiresFrom=$day&expiresTo=$day")
Check ($result.Count -eq 1 -and $result[0].name -eq '筛选牛奶') 'same day date range inclusive'
$null=Call 'invalid sort rejected' GET "$prefix&sort=UNKNOWN" $null 400
$null=Call 'reversed dates rejected' GET "$prefix&expiresFrom=2026-11-02&expiresTo=2026-11-01" $null 400
$null=Call 'invalid date rejected' GET "$prefix&expiresFrom=2026-02-30" $null 400
[pscustomobject]@{checkedAt=(Get-Date -Format o);baseUrl=$BaseUrl;username=$username;familyId=$family.id;fridgeId=$fridge.id;passed=$checks.Count;checks=$checks} | ConvertTo-Json -Depth 6
