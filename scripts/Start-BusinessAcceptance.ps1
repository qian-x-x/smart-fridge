param(
    [switch]$SkipBuild,
    [ValidateSet('Core', 'Auth', 'Fault', 'Recipe', 'All')][string]$Scope = 'Core'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskAgent = Join-Path $taskRoot 'infra/skywalking/agent'
if (-not (Test-Path -LiteralPath (Join-Path $taskAgent 'skywalking-agent.jar'))) {
    throw '真实链路验收需要 SkyWalking agent；准备方式见开发运行手册。'
}
foreach ($taskDependency in @('smart-fridge-mysql-core', 'smart-fridge-redis', 'smart-fridge-nacos', 'smart-fridge-seata', 'smart-fridge-skywalking-oap')) {
    $taskRunning = docker ps --filter "name=^/$taskDependency$" --format '{{.Names}}'
    if (-not $taskRunning) { throw "请先启动依赖：$taskDependency" }
}
if (-not $SkipBuild) {
    Push-Location (Join-Path $taskRoot 'backend')
    try {
        mvn -q -pl gateway-service,auth-family-service,fridge-service,recipe-service -am '-DskipTests' package
        if ($LASTEXITCODE -ne 0) { throw '后端打包失败' }
    } finally { Pop-Location }
}
# Dedicated schemas and a dedicated Nacos group protect existing development data.
$taskSql = @'
CREATE DATABASE IF NOT EXISTS auth_business CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS fridge_business CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS recipe_business CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON auth_business.* TO 'smart_fridge'@'%';
GRANT ALL PRIVILEGES ON fridge_business.* TO 'smart_fridge'@'%';
GRANT ALL PRIVILEGES ON recipe_business.* TO 'smart_fridge'@'%';
'@
$taskSql | docker exec -i -e MYSQL_PWD=smart_fridge_root_dev smart-fridge-mysql-core mysql --user=root --default-character-set=utf8mb4
if ($LASTEXITCODE -ne 0) { throw '验收数据库初始化失败' }

if ($Scope -in @('Fault', 'All')) {
    $taskProxy = 'sf-business-proxy'
    docker rm -f $taskProxy 2>$null | Out-Null
    $taskFixture = Join-Path $taskRoot 'scripts/fixtures/workspace-fault-proxy.py'
    docker run -d --name $taskProxy --network smart-fridge -p 127.0.0.1:18089:8099 -v "${taskFixture}:/proxy.py:ro" python:3.11-alpine python /proxy.py | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '验收故障代理启动失败' }
}

$taskJdbc = 'useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true'
$taskSecret = 'acceptance-only-family-workspace-secret-isolated-from-development-2026'
$taskServices = @(
    @{ Name = 'sf-business-auth'; Module = 'auth-family-service'; Port = 8081; HostPort = 18081; Db = 'auth_business'; Group = 'SMART_FRIDGE_BUSINESS'; Extra = @{} },
    @{ Name = 'sf-business-fridge'; Module = 'fridge-service'; Port = 8082; HostPort = 18082; Db = 'fridge_business'; Group = 'SMART_FRIDGE_BUSINESS'; Extra = @{} },
    @{ Name = 'sf-business-recipe'; Module = 'recipe-service'; Port = 8083; HostPort = 18083; Db = 'recipe_business'; Group = 'SMART_FRIDGE_BUSINESS'; Extra = @{} },
    @{ Name = 'sf-business-gateway'; Module = 'gateway-service'; Port = 8080; HostPort = 18080; Db = ''; Group = 'SMART_FRIDGE_BUSINESS'; Extra = @{AUTH_SERVICE_URL = 'http://sf-business-auth:8081'} },
    @{ Name = 'sf-business-auth-fault'; Module = 'auth-family-service'; Port = 8081; HostPort = 18091; Db = 'auth_business'; Group = 'SMART_FRIDGE_BUSINESS_FAULT'; Extra = @{
        FRIDGE_SERVICE_URL = 'http://sf-business-proxy:8099'
        FEIGN_READ_TIMEOUT_MS = '1000'
        WORKSPACE_SLOW_CALL_MS = '150'
        WORKSPACE_CIRCUIT_MIN_REQUESTS = '2'
        WORKSPACE_QPS = '20'
    }}
)
$taskServices = @($taskServices | Where-Object {
    $Scope -eq 'All' -or
    ($Scope -eq 'Auth' -and $_.Name -eq 'sf-business-auth') -or
    ($Scope -eq 'Core' -and $_.Name -in @('sf-business-auth', 'sf-business-fridge', 'sf-business-gateway')) -or
    ($Scope -eq 'Fault' -and $_.Name -eq 'sf-business-auth-fault') -or
    ($Scope -eq 'Recipe' -and $_.Name -eq 'sf-business-recipe')
})
foreach ($taskService in $taskServices) {
    $taskJar = Join-Path $taskRoot "backend/$($taskService.Module)/target/$($taskService.Module)-0.1.0-SNAPSHOT.jar"
    if (-not (Test-Path -LiteralPath $taskJar)) { throw "缺少 jar：$taskJar" }
    $taskEnvironment = @{
        TZ = 'Asia/Shanghai'
        NACOS_ADDR = 'nacos:8848'
        SPRING_CLOUD_NACOS_DISCOVERY_GROUP = $taskService.Group
        REDIS_HOST = 'redis'
        REDIS_PASSWORD = 'smart_fridge_dev'
        MYSQL_CORE_USER = 'smart_fridge'
        MYSQL_CORE_PASSWORD = 'smart_fridge_dev'
        SEATA_ADDR = 'smart-fridge-seata:8091'
        JWT_SECRET = $taskSecret
        JAVA_TOOL_OPTIONS = '-Xms32m -Xmx256m -XX:MaxDirectMemorySize=64m'
        SW_LOGGING_DIR = '/tmp/skywalking-logs'
    }
    if ($taskService.Db) { $taskEnvironment.MYSQL_CORE_URL = "jdbc:mysql://mysql-core:3306/$($taskService.Db)?$taskJdbc" }
    foreach ($taskKey in $taskService.Extra.Keys) { $taskEnvironment[$taskKey] = $taskService.Extra[$taskKey] }
    docker rm -f $taskService.Name 2>$null | Out-Null
    $taskArguments = @('run', '-d', '--name', $taskService.Name, '--network', 'smart-fridge',
        '-p', "127.0.0.1:$($taskService.HostPort):$($taskService.Port)",
        '-v', "${taskJar}:/app/app.jar:ro", '-v', "${taskAgent}:/skywalking/agent:ro")
    foreach ($taskKey in $taskEnvironment.Keys) { $taskArguments += @('-e', "$taskKey=$($taskEnvironment[$taskKey])") }
    $taskArguments += @('eclipse-temurin:17-jre', 'java', '-javaagent:/skywalking/agent/skywalking-agent.jar',
        "-Dskywalking.agent.service_name=$($taskService.Name)", '-Dskywalking.collector.backend_service=skywalking-oap:11800', '-jar', '/app/app.jar')
    & docker @taskArguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "启动失败：$($taskService.Name)" }
    # Start and warm each JVM before the next one to avoid simultaneous
    # SkyWalking class loading exhausting Docker Desktop's startup resources.
    $taskDeadline = (Get-Date).AddMinutes(5)
    $taskReady = $false
    while ((Get-Date) -lt $taskDeadline) {
        try {
            $taskHealth = Invoke-RestMethod "http://127.0.0.1:$($taskService.HostPort)/actuator/health" -TimeoutSec 3
            if ($taskHealth.status -eq 'UP') { $taskReady = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $taskReady) { throw "未就绪：$($taskService.Name)，请查看该容器日志" }
    Write-Output "UP $($taskService.Name) :$($taskService.HostPort)"
}
Write-Output '真实业务验收入口：http://127.0.0.1:18080；失败代理仅用于隔离验收。'
