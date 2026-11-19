#Requires -Version 7.0
param()
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $taskRoot 'docs/reviews/evidence/2026-11-10-quiet-white'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$schema = 'recipe_ui_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
if ($schema -notmatch '^recipe_ui_[0-9_]+$') { throw 'Unexpected test schema name' }
$label = 'xiaoyi-quiet-white-20261110'
$recipeName = 'sf-quiet-white-recipe'
$gatewayName = 'sf-quiet-white-gateway'
foreach ($name in @($recipeName,$gatewayName)) {
    $existing = docker ps -a --filter "name=^/$name$" --format '{{.Names}}'
    if ($existing) {
        $owner = docker inspect $name --format '{{index .Config.Labels "codex.acceptance"}}'
        if ($owner -ne $label) { throw "Refusing to replace an unowned container: $name" }
        docker rm -f $name | Out-Null
    }
}
$sql = "CREATE DATABASE $schema CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; GRANT ALL PRIVILEGES ON $schema.* TO 'smart_fridge'@'%';"
$sql | docker exec -i -e MYSQL_PWD=smart_fridge_root_dev smart-fridge-mysql-core mysql --user=root --default-character-set=utf8mb4
if ($LASTEXITCODE -ne 0) { throw 'Could not initialize isolated recipe schema' }

function Start-CheckedService([string]$Name,[string]$Module,[int]$Port,[int]$HostPort,[hashtable]$Extra) {
    $jar = Join-Path $taskRoot "backend/$Module/target/$Module-0.1.0-SNAPSHOT.jar"
    if (-not (Test-Path -LiteralPath $jar)) { throw "Build the module first: $Module" }
    $envs = @{
        TZ='Asia/Shanghai'; SPRING_PROFILES_ACTIVE='local'; NACOS_ENABLED='false'
        SPRING_CLOUD_NACOS_CONFIG_IMPORT_CHECK_ENABLED='false'
        JAVA_TOOL_OPTIONS='-Xms32m -Xmx192m -XX:MaxDirectMemorySize=48m'
    }
    foreach ($key in $Extra.Keys) { $envs[$key]=$Extra[$key] }
    $arguments = @('run','-d','--name',$Name,'--label',"codex.acceptance=$label",'--network','smart-fridge',
        '-p',"127.0.0.1:${HostPort}:$Port",'-v',"${jar}:/app/app.jar:ro")
    foreach ($key in $envs.Keys) { $arguments += @('-e',"$key=$($envs[$key])") }
    $arguments += @('eclipse-temurin:17-jre','java','-jar','/app/app.jar')
    & docker @arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not start $Name" }
    $ready=$false
    $deadline=(Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        try {
            $health=Invoke-RestMethod "http://127.0.0.1:$HostPort/actuator/health" -TimeoutSec 3
            if ($health.status -eq 'UP') { $ready=$true;break }
        } catch {}
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { docker logs --tail 35 $Name;throw "Not healthy: $Name" }
    Write-Output "UP $Name :$HostPort"
}

Start-CheckedService $recipeName 'recipe-service' 8083 18083 @{
    MYSQL_CORE_URL="jdbc:mysql://mysql-core:3306/${schema}?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true"
    MYSQL_CORE_USER='smart_fridge'; MYSQL_CORE_PASSWORD='smart_fridge_dev'
}
$gatewaySettings = @{
    AUTH_SERVICE_URL='http://sf-auth:8081'; AUTH_FAMILY_ROUTE_URI='http://sf-auth:8081'
    FRIDGE_ROUTE_URI='http://sf-fridge:8082'; RECIPE_ROUTE_URI="http://${recipeName}:8083"
}
# Reuse the current local gateway's signing configuration without printing it.
$currentGateway = (docker inspect sf-gateway | ConvertFrom-Json)[0]
$jwt = $currentGateway.Config.Env | Where-Object { $_.StartsWith('JWT_SECRET=') } | Select-Object -First 1
if ($jwt) { $gatewaySettings.JWT_SECRET=$jwt.Substring('JWT_SECRET='.Length) }
Start-CheckedService $gatewayName 'gateway-service' 8080 18080 $gatewaySettings
$context = @{date='2026-11-10';schema=$schema;recipeBase='http://127.0.0.1:18083';gateway='http://127.0.0.1:18080';
    recipeContainer=$recipeName;gatewayContainer=$gatewayName;scope='Isolated recipe schema and gateway; existing local auth/fridge services reused; no deployment'}
$context | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'acceptance-context.json') -Encoding utf8
$withoutIdentity = Invoke-WebRequest 'http://127.0.0.1:18083/api/v1/recipes' -SkipHttpErrorCheck
if ($withoutIdentity.StatusCode -ne 401) { throw 'Recipe identity guard did not reject missing identity' }
$catalog=Invoke-RestMethod 'http://127.0.0.1:18083/api/v1/recipes' -Headers @{'X-User-Id'='7'}
if ($catalog.data.Count -ne 18) { throw "Expected eighteen recipes, got $($catalog.data.Count)" }
$catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $evidence 'mysql-recipe-catalog.json') -Encoding utf8
Write-Output 'MySQL catalog: 18 recipes; missing identity: 401. Existing development schemas untouched.'
Write-Output 'Acceptance gateway: http://127.0.0.1:18080'
