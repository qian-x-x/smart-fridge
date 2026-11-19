# 小易冰箱

查食材，看菜谱，都容易。面向家庭的食材管理作品，采用 V2.0 静白全景界面与灰白黑厨房。正式工程由 Flutter 用户端、Spring Boot 微服务、数据库迁移、运行编排和验收资料组成。

更新日期：2026-11-19。用户已确认现有功能满足作品要求，当前功能范围按已实现能力收敛。完整目录与清理清单见 [项目目录](docs/项目目录.md)，最新验证见 [开发状态](docs/开发状态.md)。

## 当前功能

| 模块 | 可用能力 |
| --- | --- |
| 账号 | 注册、登录、令牌刷新、登出撤销与演示浏览 |
| 家庭 | 创建并初始化默认冰箱、邀请码加入、家庭切换、成员角色与所有权管理 |
| 食材 | 新增、查询筛选、编辑、移动、使用、丢弃、临期查看与过期清理 |
| 操作记录 | 流水查询、支持的单条操作撤销与恢复 |
| 菜谱 | 18 道图文菜谱、原料与步骤、库存规则匹配、做饭确认及事务扣减 |
| 可视化 | Web 实时 Three.js 厨房、双门及抽屉开合；Android 厨房参考图与业务表单 |
| 微服务 | Gateway/JWT、Nacos、Feign、Sentinel、Seata 和 SkyWalking 接入真实家庭初始化 |

家庭信息通过重新加载同步；冰箱使用默认四区及六个容器；临期阈值由服务端统一配置；食材扣减在操作时间线查看。图片随应用打包。家庭补货就是食材入库。

日常后端运行 **gateway、auth-family、fridge、recipe 四个应用**。已实现的 order/stock 历史示例默认关闭，需显式使用 `Start-Services.ps1 -IncludeLegacyDemo`。Vue 管理端原型及未接入的 MinIO/RocketMQ 已从有效工程移除。

## 快速开始

环境基线：JDK 17、Maven 3.9、Flutter 3.47.8 / Dart 3.13.7、Docker Desktop；Node.js 22 用于辅助脚本与离线演示检查。

```powershell
# 基础数据库、Redis 与 Nacos
.\scripts\Start-Core.ps1

# 新环境先按运行手册准备 Seata、SkyWalking 和 Agent
# 已有本机容器可以直接恢复
docker start smart-fridge-seata smart-fridge-skywalking-oap smart-fridge-skywalking-ui
.\scripts\Start-Services.ps1

# 用户端开发运行
Push-Location apps/fridge-app
flutter pub get --enforce-lockfile
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
Pop-Location
```

完整环境也可使用 `Start-Full.ps1`，包含 core 依赖及 Seata、Sentinel Dashboard、SkyWalking；不再声明对象存储或消息队列。启动顺序、Agent、Nginx 和网络配置见 [开发运行手册](docs/开发运行手册.md) 及 [交付运行说明](docs/交付/交付与运行说明.md)。

正式 Web 启动后可访问 [127.0.0.1:3030](http://127.0.0.1:3030)，页面通过同源代理访问 8080 网关。用于验收的独立运行环境见 [实施与预览](docs/design/ui-redesign-2026-11-10/实施与预览.md)。

无需后端的独立演示可直接打开 [apps/frontend-demo/index.html](apps/frontend-demo/index.html)，使用本地模拟数据；其结果不能作为真实后端验收证据。

## 目录

```text
apps/fridge-app/                  正式 Flutter Web / Android 用户端
apps/frontend-demo/               已完成的独立离线 HTML 演示
backend/
  common-core/                    API、异常与追踪公共模块
  service-parent/                 业务服务父模块
  gateway-service/                统一入口、JWT 与路由
  auth-family-service/            账号、家庭、成员及工作区事务
  fridge-service/                 冰箱、食材、流水与做饭记录
  recipe-service/                 菜谱目录、原料与步骤
  order-service/                  可选历史订单技术示例
  stock-service/                  可选历史库存技术示例
contracts/openapi/                OpenAPI 契约
infra/compose/                    core / full Compose
infra/mysql/                      正式与历史示例的数据库初始化
infra/web/                        Nginx 同源代理
scripts/                          启动、构建与验收工具
docs/项目目录.md                  详细目录与最终功能范围
docs/开发状态.md                  最新验证、实现限制与历史记录
docs/答辩/                        技术说明和 50 道答辩问答
docs/reviews/                     阶段审查及证据
```

正式请求统一由 Gateway `8080` 的 `/api/v1` 进入。认证家庭、冰箱、菜谱服务分别为 8081、8082、8083。OWNER/EDITOR 可按权限写入，VIEWER 只读。完整请求模型见 [OpenAPI](contracts/openapi/smart-fridge-v1.yaml)。

## 验证与交付

```powershell
Push-Location backend
mvn test
Pop-Location

Push-Location apps/fridge-app
dart analyze lib test
flutter test --no-pub
flutter build web --release --no-pub
Pop-Location

docker compose --env-file infra/compose/.env.example -f infra/compose/compose.core.yml config --quiet
docker compose --env-file infra/compose/.env.example -f infra/compose/compose.full.yml config --quiet
```

Web / Android 完整构建使用 `scripts/Build-Flutter.ps1`，保持锁文件并使用 ASCII 构建副本。Android 当前采用模板 debug 签名，构建通过不能替代真机验收。硬件 GPU、多浏览器、容量、高可用及新电脑复现的实际状态见开发记录。

当前工作区源码打包使用 `python scripts/Package-Source.py`，输出 `交付包/小易冰箱-源码-YYYYMMDD.zip`，包含最新未提交改动，并附逐文件清单、SHA256 和 [解压与使用说明](docs/交付/源码解压与使用说明.md)。`--dry-run` 可只查看打包范围；已有同名文件不会被覆盖，可用 `--archive-name` 指定新文件名。

原 `scripts/Package-Delivery.py` 仍用于已提交、干净 Git 版本的完整源码与构建产物交付。源码快照与历史完整交付包分开，旧压缩包不会自动更新。

## 文档入口

- [当前目录与功能范围](docs/项目目录.md)
- [开发状态](docs/开发状态.md) 与 [运行手册](docs/开发运行手册.md)
- [答辩 Word](docs/答辩/小易冰箱技术使用说明与答辩问答.docx) · [文字版](docs/答辩/小易冰箱技术使用说明与答辩问答.md)
- [V2.0 设计基线](docs/superpowers/specs/2026-11-10-quiet-white-kitchen.md)
- [当前预览说明](docs/design/ui-redesign-2026-11-10/实施与预览.md)
- [功能收敛审查](docs/reviews/2026-11-10-scope-cleanup.md)

旧版需求、设计、审查与提交材料保留日期，作为过程记录；其中的扩展计划由当前功能范围替代。

Three.js 运行文件与许可证位于 `apps/fridge-app/web/vendor/`。WebGL 不可用时可使用同数据库存清单。数据库变更通过 Flyway，每阶段记录审查与实际验证，未经指示不提交、推送或部署。
