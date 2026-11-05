# 小易冰箱

查食材，看菜谱，都容易。面向家庭用户的食材、菜谱与补货应用，采用「暖橙食集」视觉。仓库统一管理 Flutter 用户端、Vue 运营后台、7 个 Spring Boot 服务、基础设施编排和验收文档。

远程私有仓库：[qian-x-x/smart-fridge](https://github.com/qian-x-x/smart-fridge)

## 当前状态

当前已完成 **S0 工程决策 + S1 第一轮底座**，并完成用户端 WebGL 真 3D 视觉升级。**S2 核心纵切及菜谱/家庭接口已可联调**：冰箱与食材支持真实 CRUD 和操作日志；Flutter 首页已接入真实数据；家庭页读取真实家庭并可创建家庭；菜谱页读取 MySQL 菜谱目录并结合冰箱库存计算推荐匹配。

家庭协作、所有权转交、多家庭切换及无冰箱创建引导已通过真实 Gateway/MySQL 双账号验收。食材清单已支持名称、分类、多标签、分区、到期状态、日期范围组合筛选及四种排序，并修复家庭切换期间旧请求回写问题。下一纵切补齐时间线撤销/恢复和冰箱结构配置。

当前前端采用 **V1.5 暖橙食集**：奶油底色、陶土橙、暖木、圆角卡片和胶囊按钮。桌面窄导航轨与库存侧栏、手机底导航、登录、菜谱、家庭与业务弹层统一样式；运营端同步改版。切换主页面保留查询、滚动和三维场景，隐藏时暂停模型；按钮增加悬停/按压反馈，新增表单关闭前保护草稿。实时厨房保留双门、独立抽屉、共享冷藏内腔与当前家庭库存同步。

最新[分类与开合状态修复](docs/reviews/2026-10-31-category-door-controls.md)：分类改为预设选择，门/抽屉按钮独立同步高亮；Flutter 74 项、Three.js 5 项通过，静态分析无问题，Web/Android 构建成功。32 种开合组合及手机选择分类后真实写入/查询均通过浏览器验收。Android 包为测试签名，未进行真机验收。

此前[暖橙食集与品牌阶段审查](docs/reviews/2026-10-31-warm-harvest-xiaoyi.md)完成整体样式、Web/Vue/Android 构建、真实新增、空家庭隔离与只读权限复验；[整体实际截图](docs/design/warm-harvest/验收记录.md)保留该阶段记录。

此前[全仓审查及接口复验](docs/reviews/2026-10-31-full-code-api-audit.md)修复会话及接口边界，Java 47 项与 Gateway 190 个断言为前一轮结果，本轮未重跑完整后端矩阵。推送通知、布局编辑等未实现能力在界面中明确说明。

| 模块 | 当前能力 |
| --- | --- |
| Flutter | 登录、注册、会话安全存储与自动续期、真实家庭冰箱数据、WebGL 真 3D 冰箱、食材增改移用丢、演示入口 |
| Vue 管理端 | 登录、ECharts 看板、菜谱、商品库存、订单页面 |
| 后端 | Maven BOM、7 个服务、Gateway JWT、认证家庭、冰箱食材、菜谱目录纵切 |
| 数据 | Flyway、账号/家庭、冰箱、食材、操作日志、菜谱和原料，H2 集成测试 |
| 基础设施 | core/full 两套 Compose，MySQL 双实例、Nacos、Redis、MinIO 及课程组件 |
| 质量 | Maven 测试、Flutter 测试、Flutter Web release、Vue 生产构建 |

仍未实现的主业务包括：时间线撤销/恢复、WebSocket 家庭同步、做饭扣减、补货事务、Seata/Sentinel/RocketMQ/SkyWalking 的真实业务证据、正式素材和 Android release 签名。

## 快速开始

环境基线：JDK 17、Maven 3.9、Flutter 3.47.8、Node.js 22、Docker Desktop。

```powershell
# 启动 Nacos、MySQL、Redis、MinIO
.\scripts\Start-Core.ps1

# 后端全模块测试
cd backend
mvn test

# 用户端
cd apps/fridge-app
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# 运营后台
cd apps/admin-web
npm run dev
```

详细启动顺序、端口和故障处理见 [开发运行手册](docs/开发运行手册.md)。

## 目录

```text
apps/fridge-app/                  Flutter Android/Web
apps/admin-web/                   Vue 3 运营后台
backend/
  common-core/                    统一 API、异常和追踪
  gateway-service/                统一入口与 JWT
  auth-family-service/            账号与家庭纵切
  fridge-service/                 冰箱、分区、食材与操作日志
  recipe-service/                 菜谱目录、原料与步骤
  stock-service/                  商品库存骨架
  order-service/                  订单领域骨架
  notification-service/           通知领域骨架
contracts/openapi/                OpenAPI 3 契约
infra/compose/                    core/full Compose
infra/mysql/                      双实例初始化 SQL
docs/                             评审、设计、追踪和运行文档
```

## 当前 API

所有客户端请求从 Gateway `8080` 进入，统一前缀 `/api/v1`。

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/introspect`
- `POST /api/v1/families`
- `GET /api/v1/families`
- `GET /api/v1/families/{familyId}`
- `POST /api/v1/families/join`
- `GET /api/v1/families/{familyId}/members`
- `PATCH /api/v1/families/{familyId}/members/{userId}`
- `DELETE /api/v1/families/{familyId}/members/{userId}`
- `POST /api/v1/families/{familyId}/transfer-owner`
- `POST /api/v1/fridges`
- `GET /api/v1/fridges?familyId={familyId}`
- `GET /api/v1/fridges/{fridgeId}`
- `GET /api/v1/foods?fridgeId={fridgeId}&query={name}`
- `POST /api/v1/foods`
- `GET /api/v1/foods/{foodId}`
- `PUT /api/v1/foods/{foodId}`
- `DELETE /api/v1/foods/{foodId}?version={version}`
- `POST /api/v1/foods/{foodId}/move`
- `POST /api/v1/foods/{foodId}/consume`
- `GET /api/v1/recipes`
- `GET /api/v1/recipes/{recipeId}`

认证家庭服务运行在 `8081`，冰箱食材服务运行在 `8082`，菜谱服务运行在 `8083`。OWNER 可配置冰箱结构；OWNER/EDITOR 可修改食材；VIEWER 只读。库存、订单和通知服务当前仍提供 `/ping` 与 Actuator 健康端点。

## 关键文档

- [工程设计](docs/superpowers/specs/2026-10-26-smart-fridge-design.md)
- [S0 需求追踪基线](docs/S0-需求追踪基线.md)
- [乙方开工评审](docs/乙方开工评审.md)
- [OpenAPI 契约](contracts/openapi/smart-fridge-v1.yaml)
- [开发运行手册](docs/开发运行手册.md)
- [开发设计说明 V1.4](可视化冰箱APP开发设计说明-V1.4.docx)
- [V1.5 小易冰箱暖橙食集设计与交互](docs/superpowers/specs/2026-10-31-warm-harvest-xiaoyi.md)
- [当前实际截图及验收](docs/design/warm-harvest/验收记录.md)
- [历史 V1 写实厨房设计与交互](docs/superpowers/specs/2026-10-31-realistic-kitchen-ui.md)
- [当前开发状态](docs/开发状态.md)

V1.5 暖橙食集补充说明是当前视觉与交互基线；V1.4 Word 文档保留几何模型及结构设计，V1.3 及更早文件保留为历史需求记录。账号、家庭权限和库存等业务规则继续沿用工程契约。

Web 端 Three.js 运行文件已随 `apps/fridge-app/web/vendor` 本地打包，许可证见同目录
`THREE-LICENSE.txt`。3D 场景不依赖外部 CDN；浏览器不支持 WebGL 时显示错误状态，并可切换到冰箱表格清单。

## 协作约定

- `main` 保持可编译、可验证。
- 数据库变更通过 Flyway；不得手工修改已发布迁移。
- 密钥、真实用户图片和未授权素材不得提交。
- 中间件必须随真实业务接入，不后补静态声明。
- 每个阶段以 AC 编号关联自动化测试或可复现演示。
