# S3 操作时间线、撤销恢复与做饭扣减审查

日期：2026-11-06。范围：S3 纵切第一条主线——食材操作时间线查询、单条撤销/恢复、做饭确认与幂等扣减，以及对应的契约、Flutter 界面和测试。结论：代码审查、自动化验证与真实环境端到端验收（7 个服务 + MySQL/Redis/网关 + 浏览器）均通过；WebSocket 实时同步仍未实现，是 S3 唯一未闭环子项。

## 1. 本轮改动

### 后端（fridge-service）

| 文件 | 作用 |
| --- | --- |
| `db/migration/V3__operations_and_cooking.sql` | 给 `food_operation` 增加 `reverted_by_operation_id` 自引用列；新增 `cook_record`、`cook_record_item` 两张表与唯一约束 |
| `food/FoodOperationRepository` | 时间线查询（按冰箱、可选食材过滤、倒序、条数上限）、撤销状态 CAS、流水写入 |
| `food/FoodOperationService` | 撤销/恢复状态机、目标状态计算、并发与版本校验 |
| `food/FoodOperationController` | `GET /fridges/{id}/operations`、`POST /foods/{id}/operations/{opId}/undo\|restore` |
| `food/FoodViewMapper` | 从 `FoodService` 抽出的到期天数映射，时间线与食材接口共用同一口径 |
| `food/FoodRepository` | 新增 `lockRecordById`（包含已丢弃行）、`applyState`（快照写回）、`consumeForCook`（带数量下限的 CAS 扣减）；操作流水支持备注 |
| `cook/*` | 做饭记录的请求/视图/仓储/服务/控制器，`requestId` 唯一键实现幂等 |
| `family/FridgeAccessGuard` | 统一“取冰箱 + 校验家庭角色”，替换 `FoodService` 内重复的权限代码 |

状态机约定：只有 `MOVE`、`CONSUME`、`COOK`、`DISCARD` 可撤销；`ADD`/`UPDATE` 因原始字段不足以还原而明确拒绝（409）。撤销写入 `UNDO` 流水并回填原操作的 `reverted_by_operation_id`；恢复写入 `RESTORE` 流水并清空该列，因此同一操作可以“撤销→恢复→再撤销”循环。`UNDO`/`RESTORE` 自身不可再撤销。

### 契约

`contracts/openapi/smart-fridge-v1.yaml` 增加 4 条路径（时间线、undo、restore、cook-records 的 GET/POST 计 1 条路径 2 个操作）、`OperationId` 参数、`FoodOperation`/`CookRequest`/`CookItemRequest`/`CookItem`/`CookRecord` 模型。做饭确认在重放时返回 200、首次创建返回 201 并带 `Location`。

### 客户端

| 文件 | 作用 |
| --- | --- |
| `features/fridge/domain/food_operation.dart` | 时间线条目模型、可撤销/可恢复判定、中文摘要 |
| `data/api_fridge_repository.dart` | 新增 `loadOperations`、`undoOperation`、`restoreOperation`、`cook`；演示会话直接拒绝读写 |
| `application/fridge_workspace_controller.dart` | 对应四个用例，做饭请求 ID 由时间戳加随机后缀生成，满足 `^[A-Za-z0-9_-]{8,64}$` |
| `widgets/food_timeline_sheet.dart` | 操作记录弹层：加载/空/失败状态、撤销与恢复按钮、只读成员隐藏按钮 |
| `widgets/cook_confirm_sheet.dart` | 做饭确认弹层：勾选食材、0.5 步进调整数量（不超过库存）、整批提交、失败保留原因 |
| `fridge_home_page.dart` / `recipes_page.dart` | 库存面板加“记录”入口；菜谱详情加“用现有食材做这道菜” |

## 2. 审查关注点与结论

- **权限**：时间线读走 `requireMember`，撤销/恢复/做饭走 `requireEditor`；VIEWER 读时间线 200、写接口 403，与既有食材写入口径一致。演示账号在前端隐藏入口并在仓储层拒绝。
- **家庭与冰箱隔离**：操作查询按 `fridge_id` 收窄，撤销时校验操作所属食材与路径 `foodId` 一致；跨冰箱操作返回 404。做饭逐条校验食材属于目标冰箱。
- **并发与竞态**：撤销先用 `SELECT ... FOR UPDATE` 锁食材行，再用 `WHERE reverted_by_operation_id IS NULL` 的 CAS 抢占；同一操作并发撤销只有一个成功，其余 409。做饭以 `(fridge_id, request_id)` 唯一键抢占，重复请求返回既有记录。
- **失败恢复**：做饭先完成全部条目校验（存在性、归属、数量、版本）再落库，扣减与记录写入同一事务；任一条目失败时整批回滚，测试断言食材数量、`cook_record`、`COOK` 流水均未变化。撤销过程中 `markUndone` 失败会抛异常回滚，不会出现“食材已改、流水未标”的中间态。
- **接口兼容**：既有食材接口的请求/响应未改；`FoodService` 的到期天数计算迁移到 `FoodViewMapper` 后结果不变，20 项既有冰箱接口测试全部通过。新增 `V3` 迁移只加列与加表，不改既有列。
- **数据一致性**：做饭记录保存菜谱名称快照，菜谱改名不影响历史记录；`cook_record_item` 同时存 `food_item_id` 与名称、单位快照。`DISCARD` 的撤销通过不过滤 `status` 的加锁读取实现，避免“已丢弃就查不到”。

## 3. 审查中发现并修复的问题

1. `CookApiIntegrationTest` 的 VIEWER 用例最初复用做饭 helper，而 helper 内部会把角色重置为 EDITOR，导致用例假通过；改为直接构造请求并显式设置只读角色。
2. `FoodRecord` 原为包内可见，`cook` 包无法引用；改为 `public record`，不改字段与语义。
3. Riverpod 3 的 `AsyncValue` 没有 `valueOrNull`，菜谱页改用 `AsyncData` 模式匹配取当前工作区。
4. 新增契约时，首次写入脚本因换行转义被外层 shell 处理导致锚点失配，未产生半成品文件；改用显式多行写入后校验通过。
5. 本机设置了全局 HTTP 代理，`flutter_tester` 的本地 WebSocket 握手被代理拦截，全部测试报 “Invalid WebSocket upgrade request”；已确认是环境问题，用 `NO_PROXY=127.0.0.1,localhost` 并清除代理变量后正常运行，代码未做任何规避。该命令已写入运行手册。
6. 真实浏览器联调发现做饭成功后详情弹层不关闭：`Navigator.of(context)` 取到的是 go_router 分支导航器，而两个底部弹层都挂在根导航器，`maybePop` 打不到弹层。改为 `Navigator.of(context, rootNavigator: true)` 并等待 320ms 让做饭弹层结束退场动画，复验后两个弹层一起关闭、库存与记录同步刷新。

## 4. 自动化验证

| 命令 | 目录 | 结果 |
| --- | --- | --- |
| `mvn -o test` | `backend/` | 63 项通过（common 1、gateway 9、auth-family 12、fridge 38、recipe 3） |
| `dart analyze lib test` | `apps/fridge-app` | 无问题 |
| `flutter test --no-pub` | `apps/fridge-app` | 82 项通过（原 74 项 + 时间线 3 项 + 做饭 2 项 + 仓储 3 项） |
| `node --test scripts/tests/fridge3d.test.mjs` | 仓库根 | 5 项通过 |
| `flutter build web --release --no-pub` | `apps/fridge-app` | 成功，`build/web` |
| OpenAPI 校验（PyYAML 唯一键 + 引用解析） | 仓库根 | 23 条路径、33 个模型、42 处引用，无重复键、无悬空引用 |

新增后端用例 16 项：时间线 9 项（倒序与可撤销标记、撤销扣减、二次撤销冲突与恢复、撤销丢弃、撤销移动、ADD/不存在/过期版本拒绝、VIEWER 只读、按食材过滤与未知冰箱）、做饭 7 项（整批扣减与流水、同 requestId 重放、批量失败零写入、过期版本与跨冰箱拒绝、重复条目与非法 requestId、VIEWER 拒绝、缺少网关身份）。

## 5. 真实环境端到端验收

环境：`docker compose -f compose.core.yml` 启动 MySQL 8.0.39、Redis 7.2.5、Nacos 2.4.3、MinIO；`eclipse-temurin:17-jre` 容器运行 7 个业务服务（gateway 8080、auth-family 8081、fridge 8082、recipe 8083、stock 8084、order 8085、notification 8086），全部接入 `smart-fridge` 网络；Flutter release 产物由 nginx 容器在 `:3000` 托管。`fridge_db` 已有 V1/V2 与 67 条历史食材，启动时真实执行 `V3` 迁移，新增 `cook_record`、`cook_record_item` 与 `reverted_by_operation_id`。

| 套件 | 断言 | 结果 | 脚本 |
| --- | --- | --- | --- |
| 全接口矩阵 | 135 | 135 通过 | `scripts/Smoke-ApiAudit.ps1` |
| 家庭协作与转交 | 30 | 30 通过 | `scripts/Smoke-FamilyWorkspace.ps1` |
| 组合筛选与排序 | 25 | 25 通过 | `scripts/Smoke-FoodFilters.ps1` |
| S3 时间线与做饭（本轮新增） | 29 | 29 通过 | `scripts/Smoke-S3-TimelineCooking.ps1` |
| 桌面端 UI（本轮新增） | 6 | 6 通过 | `scripts/ui-acceptance-s3.mjs` |
| **合计** | **225** | **225 通过** | [summary.json](evidence/2026-11-06-s3/summary.json) |

S3 断言覆盖：注册与建家庭、邀请码加入（默认 VIEWER）、建冰箱四分区、两份食材、使用扣减、时间线倒序与可撤销标记、撤销回补数量、UNDO 流水与原操作标记、二次撤销 409、恢复重新扣减、做饭 201 与批量扣减、同 `requestId` 重放 200 且不重复扣减、做饭记录查询、两条 COOK 流水、VIEWER 读时间线 200 / 撤销 403 / 做饭 403、跨操作 404、跨家庭 404、未知冰箱 404、菜谱经网关可达、登出撤销后旧令牌 401（打通 Redis 撤销链路）。

浏览器验收（1414 × 807 桌面视口，真实 release 构建 + 真实服务）：登录、首页真实库存渲染、菜谱详情“用现有食材做这道菜”、做饭确认弹层扣减落库、操作记录弹层、撤销（出现“已撤销”标记与“恢复”按钮、数量回补、提示“已撤销「界面鸡蛋」的这次操作”）、恢复（回到可撤销状态、提示“已恢复这次操作”）。截图：[01 登录](evidence/2026-11-06-s3/01-login-desktop.png)、[03 首页](evidence/2026-11-06-s3/03-home-desktop.png)、[04 时间线](evidence/2026-11-06-s3/04-timeline-desktop.png)、[05 撤销后](evidence/2026-11-06-s3/05-timeline-after-undo.png)、[06 恢复后](evidence/2026-11-06-s3/06-timeline-after-restore.png)。

### 真实验收中发现的问题

1. **网关容器内令牌校验不可达**：网关 `smart-fridge.auth-service-url` 默认 `http://127.0.0.1:8081`，容器内需显式传 `AUTH_SERVICE_URL` 指向 auth 容器，否则所有带令牌请求返回 503“认证服务暂时不可用”。部署配置问题，未改代码，已写入运行手册。
2. **做饭后重开同一菜谱可能 409**：菜谱匹配快照中的食材版本在扣减后会过期，接口按版本拒绝并提示“已被其他成员更新，请刷新后重试”。这是预期的乐观锁行为；详情弹层现在成功后自动关闭，回到列表即重新拉取。
3. 首页时间线入口位于库存面板标题行，桌面布局直接可见；855px 窄屏下需滚动到库存概览卡片才能点到，属于既有移动端布局，本轮未改。

## 6. 尚未完成的验收

- **WebSocket/SSE 家庭实时同步仍未实现**：多成员协作依赖刷新或重新进入页面，这是 S3 唯一未闭环子项。
- 未执行 Android 构建、真机安装、软键盘与实际 GPU 性能；APK 仍为模板 debug 签名。
- 未执行 Vue 运营端构建（本轮未改其代码）与运营端真实接口联调。
- 未做压力测试与并发写基准；撤销并发仅以行锁与唯一键保证正确性，未测吞吐。
- UI 验收脚本使用固定坐标（1414×807 桌面视口），换屏幕尺寸需重新标定，尚未做成自适应断言。

## 7. 复现方式

1. 基础设施：`cd infra/compose && docker compose --env-file .env.example -f compose.core.yml up -d`。
2. 服务：`mvn -o -DskipTests package` 后，用 `eclipse-temurin:17-jre` 容器逐个启动 7 个 jar，网络 `smart-fridge`；fridge/recipe/auth 需注入 `MYSQL_CORE_URL`、`MYSQL_CORE_USER`、`MYSQL_CORE_PASSWORD`，auth 另需 `REDIS_HOST=redis`、`REDIS_PASSWORD`，fridge 需 `SMART_FRIDGE_AUTH_SERVICE_URL=http://sf-auth:8081`，网关需 `AUTH_SERVICE_URL` 与六个 `*_ROUTE_URI`。
3. Web：`flutter build web --release` 后用 nginx 容器把 `build/web` 挂到 `:3000`。
4. 接口验收：依次执行 `scripts/Smoke-ApiAudit.ps1`、`Smoke-FamilyWorkspace.ps1`、`Smoke-FoodFilters.ps1`、`Smoke-S3-TimelineCooking.ps1`。
5. UI 验收：设置 `E2E_USER`、`E2E_PASS` 与 `UI_PLAN`（登录/记录/撤销/恢复四组坐标）后执行 `node scripts/ui-acceptance-s3.mjs`。
