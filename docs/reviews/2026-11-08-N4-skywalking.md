# N4：SkyWalking 链路追踪与部署复现审查（2026-11-08）

## 1. 本轮范围

| 分项 | 分值 | 交付物 |
| --- | --- | --- |
| D2 SkyWalking 接入 | 3 | OAP + UI + 6 个服务挂 agent，服务列表与拓扑可见 |
| F8 基于 Trace 排查问题 | 6 | 一条成功链路与一条失败链路的完整 span 树，能定位到具体一跳 |
| F9 部署复现 | 8 | 一键启动脚本、依赖与端口清单、可重复的验收脚本 |

## 2. 部署

### 2.1 组件

| 组件 | 版本 | 端口 | 说明 |
| --- | --- | --- | --- |
| OAP | 10.1.0 | 11800（gRPC 上报）/ 12800（GraphQL） | H2 存储，单机演示 |
| UI | 10.1.0 | 8088 | 连 `http://skywalking-oap:12800` |
| Java agent | 9.6.0（java17） | — | 从 `apache/skywalking-java-agent:9.6.0-java17` 镜像导出到 `infra/skywalking/agent` |

### 2.2 两个必须显式处理的点

**（1）时区**。OAP 容器默认 UTC，而 GraphQL 的时间窗口按 OAP 本地时间解析。第一次查 trace 时窗口写成 `2026-11-08 1751`，OAP 实际在 UTC 09:51，返回空列表，看起来像"agent 没上报"。启动时必须加 `-e TZ=Asia/Shanghai`，`compose.full.yml` 已同步。

**（2）Gateway 插件不在默认插件目录**。agent 的 `plugins/` 里只有 `spring-webflux-*-webclient`（客户端），没有网关插件，所以网关只记录了自己发出去的 WebClient 调用，没有 `POST /api/v1/orders` 的入口 span。真正的插件在 `optional-plugins/`：

```
apm-spring-cloud-gateway-4.x-plugin-9.6.0.jar
apm-spring-webflux-6.x-plugin-9.6.0.jar
```

拷到 `plugins/` 后重启网关，入口 span 才出现。这一步不做的话，拓扑图上"用户 → 网关"这一段是断的。

另外 agent 目录是只读挂载，而 agent 默认往 `${agent}/logs` 写日志，会持续刷 `FileNotFoundException`。启动时加 `-e SW_LOGGING_DIR=/tmp/skywalking-logs` 解决。

### 2.3 挂载方式

服务容器与 agent 用只读卷挂载，JVM 参数注入：

```
java -javaagent:/skywalking/agent/skywalking-agent.jar \
     -Dskywalking.agent.service_name=order-service \
     -Dskywalking.collector.backend_service=skywalking-oap:11800 \
     -jar /app/app.jar
```

统一由 `scripts/Start-Services.ps1` 完成：校验网络与基础设施、可选打包、逐个启动 6 个服务、轮询 actuator 健康、失败时列出未就绪的服务。

## 3. 成功链路

一次 `POST /api/v1/orders`（SKU=EGG，数量 1）的完整链路：**4 个服务、40 个 span、约 120ms**（热态；服务刚启动的首次调用因为 agent 类加载会到 5s 级别，演示前需预热一次）。

| 偏移 | 层 | 服务 | 节点 | 说明 |
| --- | --- | --- | --- | --- |
| +0 | Http | gateway-service | `/api/v1/orders` | 网关入口（Spring WebFlux） |
| +2 | Http | gateway-service | `/api/v1/auth/introspect` | 网关校验令牌，peer=sf-auth:8081 |
| +7 | Http | auth-family-service | `POST:/api/v1/auth/introspect` | 认证服务 |
| +（同期） | Cache | auth-family-service | `Lettuce/EXISTS` | 查 Redis 令牌撤销状态 |
| +14 | Http | gateway-service | `SpringCloudGateway/sendRequest` | 路由到 order，peer=172.18.0.11:8085 |
| +16 | Http | order-service | `POST:/api/v1/orders` | 下单入口 |
| +（期间） | Database | order-service | `executeUpdate` | 写 PENDING 订单 |
| +45 | Http | order-service | `/api/v1/products/EGG/deduct` | Feign 调库存 |
| +46 | Http | stock-service | `POST:/api/v1/products/EGG/deduct` | 库存扣减入口 |
| +48–82 | Database | stock-service | 多条 `execute*` + `Connection/commit` | 扣减并提交本地事务 |
| +82–101 | — | — | **无 span 的空档** | 全局事务提交 / 二阶段协调 |
| +101 | Database | order-service | `Connection/commit` | 本地事务收尾 |

**值得讲的两处细节**：

- `+16` 到 `+45` 之间 29ms 只做了一件事：写订单 + 向 TC 注册分支。订单表的 `INSERT` 只有一两毫秒，剩下的时间在等 Seata 的分支注册往返。
- `+82` 到 `+101` 之间 19ms 没有任何 span——这段是 order 侧等待全局事务提交。**Trace 上"没有 span 的时间段"本身就是信息**：说明耗时不在 SQL，而在分布式事务协调。这条把 N3 和 N4 串起来了。

证据：[trace-order.json](evidence/2026-11-08-n4/trace-order.json)、[02-skywalking-topology.png](evidence/2026-11-08-n4/02-skywalking-topology.png)。

## 4. 失败链路（F8 的排查素材）

触发方式：`POST /api/v1/orders {"sku":"MILK","quantity":2,"failAfterDeduct":true}`，接口返回 500。

链路里 **3 个 span 标红**，位置很关键：

```
gateway-service  /api/v1/orders                     error=true   ← 入口失败
gateway-service  SpringCloudGateway/sendRequest      error=true   ← 下游返回 5xx
order-service    POST:/api/v1/orders                 error=true   ← 真正的失败点
order-service    /api/v1/products/MILK/deduct        error=false  ← 调库存是成功的
stock-service    POST:/api/v1/products/MILK/deduct   error=false  ← 库存扣减成功
stock-service    Mysql/JDBC/Connection/commit        —            ← 库存已提交
order-service    Mysql/JDBC/Connection/rollback      —            ← 订单侧回滚
```

排查顺序可以直接照着讲：

1. 拓扑图上 `gateway-service`、`order-service` 是红色（成功率 < 95%），先看网关；
2. 入口 span `error=true`，但下游的 `stock-service` 那一跳 `error=false` 且 `commit` 成功——**失败不在库存**；
3. 失败集中在 `order-service` 的入口 span，且它后面跟着 `Connection/rollback`，说明异常抛在订单服务内部；
4. 结合日志里的 `演示用异常：库存已扣减，订单侧主动失败`，定位到是人为注入的失败；
5. 再回到数据库核对：库存数量没变（被 Seata 回滚）、订单没落库。

这条链路的价值在于：**只看"接口 500"无法区分是库存挂了还是订单自己失败，Trace 一眼就能看出失败发生在哪一跳，以及上下游各自的状态**。

证据：[trace-error.json](evidence/2026-11-08-n4/trace-error.json)。

## 5. 验证

| 命令 | 结果 |
| --- | --- |
| `python scripts/verify-n4-skywalking.py` | **11 / 11** |
| `python scripts/query-skywalking.py` | 导出成功链路 40 span |
| `python scripts/query-skywalking.py --error` | 导出失败链路 36 span，3 个 error |
| `mvn test` | 70 项通过（本轮未改业务代码） |
| `Smoke-ApiAudit.ps1` | 132 / 132 |

`api-acceptance.json` 的 11 项（最新一次实测 40 span / 约 120ms）：OAP 可达、6 个服务全部上报、依赖节点被发现（mysql-core / mysql-trade / redis）、登录、下单、链路捕获、覆盖 4 个服务、span 数 ≥ 20、网关入口 span、Feign 跳、MySQL+Redis 节点。

UI 截图：[01 服务列表](evidence/2026-11-08-n4/01-skywalking-dashboard.png)（6 个服务的 Load / 成功率 / 延迟 / Apdex）、[02 拓扑图](evidence/2026-11-08-n4/02-skywalking-topology.png)（网关与订单为红色，对应失败率）、[03 链路列表](evidence/2026-11-08-n4/03-skywalking-service-trace.png)。

## 6. 本轮发现的问题

1. **trace 查不到 = 时区不对**（见 2.2）。这个坑不报错，只返回空列表，很容易误判成 agent 没工作。
2. **网关插件默认不启用**（见 2.2）。不启用时网关只有客户端 span，拓扑图缺"用户 → 网关"这一段。
3. **agent 9.4 没有 Gateway 插件**，9.6 才在 `optional-plugins` 提供 4.x 版本；升级 agent 时其他插件的 jar 名带版本号，直接覆盖目录会残留旧版本，必须先移走旧目录（且要先停掉挂载它的容器，否则 Windows 上文件被占用）。
4. **冷启动 + Feign 超时会触发"分支注册失败"**：挂上 agent 后首次调用库存服务，类加载耗时超过 Feign 1500ms 读超时，order 侧已经回滚，stock 侧稍后提交时报 `branch register failed ... may be has finished`。数据是一致的（订单没落库、库存没扣），但这说明**超时时间要和链路冷启动开销一起考虑**。演示前先预热一次即可。
5. **`Start-Services.ps1` 早期版本健康检查只等 3 分钟**，挂 agent 后首次启动要加载数百个插件 jar，会误报失败。已改为每服务 5 分钟。
6. **健康检查把 `Content` 当字符串用**：PowerShell 7 的 `Invoke-WebRequest` 在响应缺少 charset 头时把 `Content` 存成 `byte[]`，`-match '"UP"'` 永远不成立，表现为"每个服务都等满 5 分钟然后 FAIL"，而服务其实早就 200。改用 `Invoke-RestMethod` 读 `$health.status` 后一次通过。
7. **OAP 堆内存不够**：默认 `-Xmx512m`，H2 存储 + 聚合都在堆里，累积几万条 span 后 `OutOfMemoryError` 直接让 GraphQL 无响应（表现为验收脚本 timeout）。已把 `JAVA_OPTS` 调到 `-Xmx1024m`，并清空一次 `skywalking-data` 卷。
8. **OAP 重启后服务注册需要时间**：agent 重新注册不是瞬时的，重启后立刻跑验收会看到"只上报了 2 个服务"。验收脚本已加最多 90 秒的重试等待。

## 7. 复现（F9）

```powershell
# 1. 基础设施（MySQL / Redis / Nacos / MinIO）
cd infra\compose
docker compose --env-file .env.example -f compose.core.yml up -d

# 2. 追踪组件（OAP 必须带时区）
docker run -d --name smart-fridge-skywalking-oap --network smart-fridge --network-alias skywalking-oap `
  -p 11800:11800 -p 12800:12800 -e TZ=Asia/Shanghai -e SW_STORAGE=h2 `
  -v skywalking-data:/skywalking/data apache/skywalking-oap-server:10.1.0
docker run -d --name smart-fridge-skywalking-ui --network smart-fridge --network-alias skywalking-ui `
  -p 8088:8080 -e TZ=Asia/Shanghai -e SW_OAP_ADDRESS=http://skywalking-oap:12800 `
  apache/skywalking-ui:10.1.0

# 3. Seata（N3 需要）
docker run -d --name smart-fridge-seata --network smart-fridge -p 8091:8091 -p 7091:7091 `
  -e SEATA_PORT=8091 -e STORE_MODE=file -e SERVER_NODE=1 `
  -v seata-data:/root/seata-server apache/seata-server:2.1.0

# 4. agent（首次或升级时执行；容器在跑的话先停服务）
docker create --name sw-agent-tmp apache/skywalking-java-agent:9.6.0-java17
docker cp sw-agent-tmp:/skywalking/agent infra/skywalking/agent
docker rm -f sw-agent-tmp
Copy-Item infra\skywalking\agent\optional-plugins\apm-spring-cloud-gateway-4.x-plugin-9.6.0.jar infra\skywalking\agent\plugins\
Copy-Item infra\skywalking\agent\optional-plugins\apm-spring-webflux-6.x-plugin-9.6.0.jar infra\skywalking\agent\plugins\

# 5. 六个服务（自动挂 agent、自动等健康）
./scripts/Start-Services.ps1

# 6. 验收
python scripts/verify-n4-skywalking.py
```

端口清单：gateway 8080、auth 8081、fridge 8082、recipe 8083、stock 8084、order 8085、SkyWalking UI 8088、OAP 11800/12800、Seata 8091/7091、MySQL core 3306 / trade 3307、Redis 6379、Nacos 8848。

## 8. 未覆盖

- **存储**：H2 单机，没有接 Elasticsearch；重启 OAP 后历史链路会丢（本轮 H2 卷保留了数据，但生产要用 ES）。
- **集群与告警**：单 OAP，没有集群与告警规则（如成功率低于阈值触发）。
- **日志采集**：只做了链路，没有接日志到 OAP（`log4j2` / `grpc log reporter`），所以"Trace 关联日志"这一层没做。
- **采样率**：默认 `sample_n_per_3_secs=1`，压测场景会大量丢链路；生产要按流量调整。
- **前端接入**：Flutter Web 没有接 SkyWalking 浏览器 agent，链路从网关开始，不含页面。
