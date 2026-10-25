param(
    [string]$BaseUrl = "http://localhost:8081"
)

$ErrorActionPreference = "Stop"
$stamp = Get-Date -Format "yyyyMMddHHmmss"
$username = "smoke_$stamp"
$password = "SmokeTest2026"

$registerBody = @{
    username = $username
    phone = $null
    displayName = "冒烟测试用户"
    password = $password
} | ConvertTo-Json

$registered = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/api/v1/auth/register" `
    -ContentType "application/json; charset=utf-8" `
    -Body $registerBody

$headers = @{ Authorization = "Bearer $($registered.data.accessToken)" }
$familyBody = @{ name = "冒烟测试家庭" } | ConvertTo-Json
$family = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/api/v1/families" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body $familyBody

$refreshBody = @{ refreshToken = $registered.data.refreshToken } | ConvertTo-Json
$refreshed = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/api/v1/auth/refresh" `
    -ContentType "application/json" `
    -Body $refreshBody

$logoutBody = @{ refreshToken = $refreshed.data.refreshToken } | ConvertTo-Json
$logout = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/api/v1/auth/logout" `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $logoutBody

$afterLogout = Invoke-WebRequest `
    -UseBasicParsing `
    -SkipHttpErrorCheck `
    -Uri "$BaseUrl/api/v1/families" `
    -Headers $headers

$result = [pscustomobject]@{
    RegisteredUser       = $registered.data.user.displayName
    Family               = $family.data.name
    FamilyRole           = $family.data.currentUserRole
    RefreshIssued        = [bool]$refreshed.data.accessToken
    LogoutCode           = $logout.code
    OldTokenAfterLogout  = $afterLogout.StatusCode
    SmokeUsername        = $username
}

$result | Format-List

if ($afterLogout.StatusCode -ne 401) {
    throw "Expected revoked access token to return 401, got $($afterLogout.StatusCode)"
}
