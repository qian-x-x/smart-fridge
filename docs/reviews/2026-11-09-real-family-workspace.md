# 真实家庭初始化：代码审查与电脑端验收

日期：2026-11-09（Asia/Shanghai）。基线：`1d9ba11`。本轮工作尚未提交。

本记录中的提交状态对应验收时点；后续用户授权的本地提交及交付整理见 [交付审查](2026-11-09-delivery.md)，不改写本记录的原始验收结果。

## 范围与结论

本轮落实用户对“技术栈必须参与实际用户业务”的要求。家庭补货是食材入库，没有购买、支付或订单。旧 order/stock 链路和 Vue 静态订单页保留为历史示例，不再作为家庭冰箱业务完成的依据。

Flutter 的“创建家庭”现在调用 `POST /api/v1/families/workspaces`：auth 创建家庭和 OWNER 成员，再通过 Nacos/Feign 调用 fridge 创建默认冰箱、四区及六个容器。Sentinel 保护创建入口和初始化依赖；Seata AT 管理两个数据库的写入；SkyWalking 记录实际调用与 SQL。创建成功后直接选中家庭，可以立即记录食材，无需再手工创建冰箱。

**本阶段代码审查、自动化验证、真实接口和电脑端 Web 验收通过。Android APK 构建通过，Android 真机验收未执行。** 用户于本轮明确选择“暂时不能，先完成电脑端验收”，因此真机项目保留待办，不作为电脑端通过的条件。压测、正式签名及管理后台业务接口也不包含在本轮通过范围内。

## 完整变更审查

对照基线审查工作区完整 tracked diff，并读取新增 Java、SQL、测试、验收脚本及故障代理；同时检查运行脚本、OpenAPI、Flutter 调用和文档的一致性。证据 JSON 检查结果字段及敏感字段，最终截图另行查看。重点如下：

| 方面 | 审查与处理 |
| --- | --- |
| 权限 | auth 从有效 JWT 提取当前用户，Feign 传递该用户及原 Authorization；fridge 继续实时查询家庭角色。Gateway 清除外部 `TX_XID` 和伪造身份头；公开工作区创建入口拒绝已绑定的外部事务上下文。未登录及 VIEWER 写入继续拒绝。 |
| 数据隔离 | 幂等键唯一约束为 `(actor_user_id, request_id)`，同用户同键异名返回 409；同键跨用户各自创建。验收使用独立数据库、Nacos 分组、端口及 JWT 密钥，故障代理不能影响正常发现路径。 |
| 异步与竞态 | 全局决定前，phase-one 家庭对普通列表、加入和管理请求不可见；仅本事务的权限回调可访问。并发相同请求只产生一个工作区。Flutter 创建完成后核对当前账号，使用权威返回值选中家庭，避免后续读取失败将成功操作显示为失败。 |
| 失败恢复 | 下游拒绝、下游实际写入后响应丢失、下游写入后超时均验证双库回滚；失败请求标记一起回滚，同一键可重试。成功响应前确认全局提交决定；确认缓存写入失败不会把真实提交变成创建失败。 |
| 接口兼容 | 保留旧 `POST /families`、`POST /fridges` 的独立语义及其引导用途；新增工作区接口由 Flutter 使用。旧家庭、食材、时间线、做饭和编辑清理矩阵重新执行。 |
| 数据迁移 | 仅新增 auth V2/V3 和 fridge V4；未修改已发布迁移。先对原始数据源执行 Flyway，再建立 Seata 代理，空库和已有开发库均实际启动。 |

审查及运行中发现并修复的问题：

1. **空库无法启动**：Seata 数据源代理可能早于 Flyway 检查 `undo_log`。改为显式迁移原始 Hikari 数据源，再构造代理；独立空库启动已通过。
2. **已提交却返回 409**：实测 AT 提交时 TC 可返回 `AsyncCommitting`。将其视为已有不可撤销提交决定，不能等待 undo 清理才承认成功；补充状态判断回归测试，并重新运行真实链路。
3. **旧事务快照可能暴露已回滚家庭**：TC 清理完成后无法仅凭 Finished 判断结果。家庭可见性检查改用独立 READ_COMMITTED 读取，并在提交状态检查后重新确认家庭仍存在；增加回滚期间旧 REPEATABLE_READ 快照的回归测试。
4. **外部事务上下文与中间态越权**：清除外部 XID、拒绝公开入口加入外部事务，并为 pending 家庭统一增加可见性屏障，覆盖列表、成员、加入和 OWNER 管理路径。
5. **提交后的客户端假失败**：去掉创建成功后必须再拉一次列表的依赖；本地选择持久化失败保留当前成功状态。网络失败或未确认冰箱时保留会话内请求键供重试。
6. **Docker 资源不足**：停用同时叠加的重复服务，JVM 最大堆设为 256 MB 并逐个等待健康。日常脚本默认只启动 gateway/auth/fridge/recipe；历史 order/stock 通过 `-IncludeLegacyDemo` 选择。
7. **浏览器脚本同步不足**：Flutter 语义文字节点不一定是可点击区域，导航改用已核对的图标位置；CDP 切换手机视口后先请求合成帧，再检查 iframe ready/settled 和实际截图。最后 10 项通过，三维产品代码未因此改动。

## 本轮自动化验证

以下均在本工作区本轮执行，未沿用历史阶段的通过数。原有 Flutter lock 保持不变，构建使用 `--no-pub`。

| 命令或检查 | 结果 | 证据 |
| --- | --- | --- |
| `cd backend; mvn -o -q '-DargLine=-Xmx320m -XX:MaxMetaspaceSize=192m' test` | 86 项，0 failure/error/skip | [计数](evidence/2026-11-09-real-business/backend-tests.json)；完整输出在本地忽略目录 `output/real-business/backend-tests-final.log` |
| `cd apps/fridge-app; flutter test --no-pub` | 92 项通过 | 本地 `output/real-business/flutter-tests.log` |
| `dart analyze lib test` | No issues found | 本地 `output/real-business/flutter-analyze.log` |
| `flutter build web --release --no-pub` | 通过 | `apps/fridge-app/build/web`，随后由实际浏览器验收 |
| `flutter build apk --release --no-pub --dart-define=API_BASE_URL=http://192.168.10.225:8080` | 通过，62,231,886 字节，模板 debug 签名 | [构建与源码核对](evidence/2026-11-09-real-business/android-build.json) |
| PyYAML 解析 OpenAPI 并解析内部引用 | 29 paths、40 schemas、156 references 全部解析 | 契约 `contracts/openapi/smart-fridge-v1.yaml` |

Android 在 ASCII 物理副本构建，以避免 Windows 中文路径工具问题；88 个源码、资源及 Android 工程文件的哈希一致，无差异。APK 的 SHA-256 为 `BE7AC5B3077BECAEE868DD3FA687EFFEBD6F23B0B22334824430C90A26A616FE`。APK 位于 `apps/fridge-app/build/app/outputs/flutter-apk/app-release.apk`，接口地址固定为本轮 Wi-Fi 地址，不能将构建成功视为手机联网验收。

## 真实环境验收

Docker Desktop 重启后，在真实 MySQL、Redis、Nacos、Seata 及 SkyWalking 环境运行隔离验收服务，非 H2 或模拟事务。故障通过单独测试代理注入，产品 API 没有故障开关。脚本与环境准备见 [开发运行手册](../开发运行手册.md#510-真实家庭初始化验收2026-11-09)。

| 验收 | 本轮结果 | 证据 |
| --- | --- | --- |
| `python scripts/verify-family-workspace.py` | 42/42，runId `6ba6412335` | [断言与数据库计数](evidence/2026-11-09-real-business/api-acceptance.json) |
| `Smoke-ApiAudit.ps1 -BaseUrl http://127.0.0.1:18080 -HealthPorts @(18080,18081,18082,18083)` | 126/126，当前四个真实服务；未包含历史交易服务 | [兼容矩阵](evidence/2026-11-09-real-business/legacy-api-audit.json) |
| `Smoke-S3-TimelineCooking.ps1 -Gateway http://127.0.0.1:18080 -OutFile docs/reviews/evidence/2026-11-09-real-business/legacy-s3.json` | 29/29 | [时间线与做饭](evidence/2026-11-09-real-business/legacy-s3.json) |
| `Smoke-FoodOps.ps1 -Gateway http://127.0.0.1:18080 -OutFile docs/reviews/evidence/2026-11-09-real-business/legacy-food-ops.json` | 26/26 | [食材编辑及清理](evidence/2026-11-09-real-business/legacy-food-ops.json) |
| `python scripts/query-family-workspace-traces.py` | 成功及下游写入后失败各一条完整跨服务链路 | [追踪汇总](evidence/2026-11-09-real-business/trace-acceptance.json) |
| `node scripts/ui-acceptance-family-workspace.mjs` | 10/10；实际 release Flutter、Edge，无浏览器异常及失败 API | [UI 断言](evidence/2026-11-09-real-business/ui-acceptance.json) |

接口断言合计 **223/223**（新业务 42 + 兼容 181）。新业务覆盖两个用户的同键隔离、OWNER 关系、四区六容器、成功重放与异名冲突、身份/XID 防伪、跨家庭读取限制、真实食材入库、VIEWER 禁写、三类远程失败的双库回滚、相同键重试、真实慢调用熔断及恢复、12 请求入口限流、4 请求同键竞态和两个 `undo_log` 最终清空。

SkyWalking 成功链路：`e29dc11543934bea885d2cf1cd2ce1e3.84.17941581341940371`；错误链路：`4f4779fd445745bfbab1daae9df99db0.113.17941580861690001`。原始 span 已保存在相邻 trace-workspace JSON，包含真实 fridge 成功写入及上游错误，配合数据库断言证明回滚；单靠 trace 不能证明数据库回滚。

Web 从登录页使用新账号创建家庭，检查 201 响应与冰箱 ID 一致，确认没有第二次手工 `POST /fridges`；返回首页加载四区，刷新仍选中该家庭。检查桌面 1400×900 和手机宽度 390×844 的场景 ready/settled，并目视检查截图。手机宽度是桌面浏览器的响应式检查，不属于 Android 真机验收。

- [创建家庭后](evidence/2026-11-09-real-business/ui-04-family-created.png)
- [桌面冰箱](evidence/2026-11-09-real-business/ui-05-new-fridge-desktop.png)
- [手机宽度冰箱](evidence/2026-11-09-real-business/ui-06-new-fridge-mobile.png)

## 日常环境恢复

完成隔离验收后停止 `sf-business-*` 验收容器，保留其数据库与证据；重新执行 `Start-Services.ps1 -SkipBuild` 和 `Start-Web.ps1`，恢复日常四个业务服务及 Web，并启动 `3000=3030` 本地转发。四个健康端点均为 UP，Nacos `SMART_FRIDGE` 中各有一个健康实例；Web `http://127.0.0.1:3000` 返回 200，未登录同源 API 返回预期 401。

原开发库迁移成功（auth V1–V3，fridge V1–V4），未清库。迁移前后核对用户 87、家庭 45、成员 51、冰箱 37、食材 96、操作 177，六表行数一致；故障及 UI 账号均创建于隔离验收库。详细快照见 [恢复证据](evidence/2026-11-09-real-business/runtime-restored.json)。旧 order/stock、MySQL trade 和 MinIO 维持按需启动，不占用当前日常业务 JVM。

## 未完成验收及风险

- Android 真机：本轮 ADB 未连接设备；用户选择先完成电脑端。待验证安装、登录、自动初始化、食材入库、家庭切换及设备网络/系统返回键。
- APK 使用模板 debug 签名，固定本轮局域网 API 地址；正式发布签名、环境配置尚未完成。
- 当前 Sentinel 默认创建限流为单实例 5 QPS、慢调用阈值 1500 ms；故障环境使用更低阈值加速保护验证。尚未执行持续压测，也未验证多实例容量。
- Seata file、SkyWalking H2 均为单机开发存储，未验证节点故障或高可用；本轮验证覆盖远程异常及超时回滚，不代表进程崩溃、磁盘丢失全部场景。
- Flutter 请求键保存在当前会话内；重启后先从家庭列表恢复，不承诺跨应用重启继续复用未知结果的创建请求键。
- 管理后台仍为静态原型，管理 API、管理员鉴权、WebSocket 同步、RocketMQ 通知及 MinIO 业务存储尚未实现；不得将其描述为已验收功能。

本轮未提交、推送或发布代码。历史 N1–N4 记录保留其当时范围；后续阶段应以本记录及开发状态中的待办继续。
