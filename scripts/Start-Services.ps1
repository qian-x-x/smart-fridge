param(
    [switch]$SkipBuild,
    [switch]$WithoutAgent
)

$ErrorActionPreference = "Stop"
# Invoke-WebRequest 默认会往输出流写进度条，轮询健康检查时会把日志刷爆。
$ProgressPreference = "SilentlyContinue"

# 一键启动 6 个业务服务（复用 infra/compose 的 core 基础设施）。
# 每个服务都是「可执行 jar + eclipse-temurin:17-jre 容器」，与 compose 里的中间件同网络，
# 因此容器内用 mysql-core / mysql-trade / nacos / redis / smart-fridge-seata 这些服务名。

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root "backend"
$agentDir = Join-Path $root "infra\skywalking\agent"
$jdbc = "useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai&useSSL=false&allowPublicKeyRetrieval=true"
$coreDb = "jdbc:mysql://mysql-core:3306"
$tradeDb = "jdbc:mysql://mysql-trade:3306"
$oap = "skywalking-oap:11800"

$useAgent = (-not $WithoutAgent) -and (Test-Path -LiteralPath (Join-Path $agentDir "skywalking-agent.jar"))
if (-not $useAgent) {
    Write-Warning "未找到 SkyWalking agent，服务将以无链路追踪模式启动。"
}

# --- 前置检查 ---
$network = docker network ls --filter name=smart-fridge --format "{{.Name}}"
if (-not $network) {
    throw "缺少 smart-fridge 网络。先执行：cd infra/compose; docker compose --env-file .env.example -f compose.core.yml up -d"
}
$core = docker ps --filter name=smart-fridge-mysql-core --filter status=running --format "{{.Names}}"
if (-not $core) {
    throw "基础设施未运行。先执行 core 编排（mysql-core / mysql-trade / nacos / redis）。"
}

if (-not $SkipBuild) {
    Write-Host "==> 打包后端（跳过测试）"
    Push-Location $backend
    mvn -q -DskipTests package
    Pop-Location
}

$services = @(
    @{
        Name = "sf-auth"; Module = "auth-family-service"; Port = 8081; AgentName = "auth-family-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            MYSQL_CORE_URL = "$coreDb/auth_db?$jdbc"
            MYSQL_CORE_USER = "smart_fridge"; MYSQL_CORE_PASSWORD = "smart_fridge_dev"
            REDIS_HOST = "redis"; REDIS_PASSWORD = "smart_fridge_dev"
        }
    },
    @{
        Name = "sf-fridge"; Module = "fridge-service"; Port = 8082; AgentName = "fridge-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            MYSQL_CORE_URL = "$coreDb/fridge_db?$jdbc"
            MYSQL_CORE_USER = "smart_fridge"; MYSQL_CORE_PASSWORD = "smart_fridge_dev"
            SMART_FRIDGE_AUTH_SERVICE_URL = "http://sf-auth:8081"
            AUTH_SERVICE_URL = "http://sf-auth:8081"
        }
    },
    @{
        Name = "sf-recipe"; Module = "recipe-service"; Port = 8083; AgentName = "recipe-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            MYSQL_CORE_URL = "$coreDb/recipe_db?$jdbc"
            MYSQL_CORE_USER = "smart_fridge"; MYSQL_CORE_PASSWORD = "smart_fridge_dev"
        }
    },
    @{
        Name = "sf-stock"; Module = "stock-service"; Port = 8084; AgentName = "stock-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            MYSQL_TRADE_URL = "$tradeDb/stock_db?$jdbc"
            MYSQL_TRADE_USER = "smart_fridge_trade"; MYSQL_TRADE_PASSWORD = "smart_fridge_trade_dev"
            SEATA_ADDR = "smart-fridge-seata:8091"
        }
    },
    @{
        Name = "sf-order"; Module = "order-service"; Port = 8085; AgentName = "order-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            MYSQL_TRADE_URL = "$tradeDb/order_db?$jdbc"
            MYSQL_TRADE_USER = "smart_fridge_trade"; MYSQL_TRADE_PASSWORD = "smart_fridge_trade_dev"
            SEATA_ADDR = "smart-fridge-seata:8091"
        }
    },
    @{
        Name = "sf-gateway"; Module = "gateway-service"; Port = 8080; AgentName = "gateway-service"
        Env = @{
            NACOS_ADDR = "nacos:8848"
            AUTH_SERVICE_URL = "http://sf-auth:8081"
        }
    }
)

foreach ($svc in $services) {
    $jar = Join-Path $backend "$($svc.Module)\target\$($svc.Module)-0.1.0-SNAPSHOT.jar"
    if (-not (Test-Path -LiteralPath $jar)) {
        throw "缺少可执行 jar：$jar（去掉 -SkipBuild 重新打包）"
    }

    docker rm -f $svc.Name 2>$null | Out-Null

    $runArgs = @("run", "-d", "--name", $svc.Name, "--network", "smart-fridge",
                 "-p", "$($svc.Port):$($svc.Port)")
    foreach ($key in $svc.Env.Keys) {
        $runArgs += @("-e", "$key=$($svc.Env[$key])")
    }
    $runArgs += @("-v", "$($jar):/app/app.jar:ro")

    $javaArgs = @()
    if ($useAgent) {
        $runArgs += @("-v", "$($agentDir):/skywalking/agent:ro")
        # agent 默认把日志写到 ${agent}/logs，而 agent 目录是只读挂载，会一直刷 FileNotFoundException。
        $runArgs += @("-e", "SW_LOGGING_DIR=/tmp/skywalking-logs")
        $javaArgs += @(
            "-javaagent:/skywalking/agent/skywalking-agent.jar",
            "-Dskywalking.agent.service_name=$($svc.AgentName)",
            "-Dskywalking.collector.backend_service=$oap"
        )
    }
    $javaArgs += @("-jar", "/app/app.jar")
    $runArgs += @("eclipse-temurin:17-jre", "java") + $javaArgs

    & docker @runArgs | Out-Null
    Write-Host ("    started " + $svc.Name)
}

# --- 等待健康 ---
Write-Host "==> 等待服务就绪"
$failed = @()
foreach ($svc in $services) {
    # 挂 agent 后首次启动要加载几百个插件 jar，3 分钟不够。
    $deadline = (Get-Date).AddMinutes(5)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        try {
            # 用 Invoke-RestMethod：PowerShell 7 的 Invoke-WebRequest 在缺少 charset 头时
            # 会把 Content 存成 byte[]，再做 -match 永远不成立，会白白忙等到超时。
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:$($svc.Port)/actuator/health" -TimeoutSec 3
            if ($health.status -eq "UP") {
                $ready = $true
                break
            }
            Start-Sleep -Seconds 3
        } catch {
            Start-Sleep -Seconds 3
        }
    }
    if ($ready) {
        Write-Host ("    UP   " + $svc.Name + " :" + $svc.Port)
    } else {
        $failed += $svc.Name
        Write-Host ("    FAIL " + $svc.Name + " :" + $svc.Port)
    }
}

Write-Host ""
Write-Host "Gateway:    http://127.0.0.1:8080"
Write-Host "SkyWalking: http://127.0.0.1:8088   (OAP gRPC 11800)"
Write-Host "Seata:      http://127.0.0.1:7091"

if ($failed.Count -gt 0) {
    throw ("以下服务未就绪：" + ($failed -join ", ") + "；查看 docker logs <name>")
}
