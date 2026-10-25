# Smart Fridge 可视化冰箱

面向家庭用户的食材、菜谱与补货应用。仓库采用单仓库管理 Flutter 用户端、Vue 运营后台、7 个 Spring Boot 服务、基础设施编排和验收文档。

远程私有仓库：[qian-x-x/smart-fridge](https://github.com/qian-x-x/smart-fridge)

## 当前状态

当前已完成 **S0 工程决策 + S1 第一轮底座**，并完成用户端 WebGL 真 3D 视觉升级。项目所有者与实施方为同一人，V1.3 开发说明作为当前产品基线推进。

| 模块 | 当前能力 |
| --- | --- |
| Flutter | 登录、注册、会话安全存储、演示入口、WebGL 真 3D 冰箱首页、菜谱页、家庭设置 |
| Vue 管理端 | 登录、ECharts 看板、菜谱、商品库存、订单页面 |
| 后端 | Maven BOM、7 个服务模块、统一响应/异常/追踪、Gateway JWT、认证家庭纵切 |
| 数据 | Flyway、账号/家庭/成员/刷新会话表、H2 集成测试 |
| 基础设施 | core/full 两套 Compose，MySQL 双实例、Nacos、Redis、MinIO 及课程组件 |
| 质量 | Maven 测试、Flutter 测试、Flutter Web release、Vue 生产构建 |

仍未实现的主业务包括：冰箱食材 CRUD、WebSocket 家庭同步、菜谱推荐与做饭扣减、补货事务、Seata/Sentinel/RocketMQ/SkyWalking 的真实业务证据、正式素材和 Android release 签名。

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
  fridge-service/                 冰箱领域骨架
  recipe-service/                 菜谱领域骨架
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

认证家庭服务可独立运行在 `8081`。其余业务服务当前提供 `/ping` 和 Actuator 健康端点。

## 关键文档

- [工程设计](docs/superpowers/specs/2026-10-26-smart-fridge-design.md)
- [S0 需求追踪基线](docs/S0-需求追踪基线.md)
- [乙方开工评审](docs/乙方开工评审.md)
- [OpenAPI 契约](contracts/openapi/smart-fridge-v1.yaml)
- [开发运行手册](docs/开发运行手册.md)
- [开发说明 V1.3](可视化冰箱APP开发说明-V1.3.docx)

V1.3 开发说明将用户端冰箱主视觉升级为 WebGL 真 3D。原 V1.2 文件继续保留，便于追踪修订。

Web 端 Three.js 运行文件已随 `apps/fridge-app/web/vendor` 本地打包，许可证见同目录
`THREE-LICENSE.txt`。3D 场景不依赖外部 CDN；浏览器不支持 WebGL 时显示错误状态，并可切换到冰箱表格清单。

## 协作约定

- `main` 保持可编译、可验证。
- 数据库变更通过 Flyway；不得手工修改已发布迁移。
- 密钥、真实用户图片和未授权素材不得提交。
- 中间件必须随真实业务接入，不后补静态声明。
- 每个阶段以 AC 编号关联自动化测试或可复现演示。
