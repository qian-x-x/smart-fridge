# 2026-11-18 全栈启动与局域网访问切换

本轮不是新功能阶段，只处理运行环境：按仓库既有启动链拉起全部服务，并确认访问方式能否从局域网进入。未修改业务代码、接口、数据库结构或 Flyway 迁移；未提交、推送或部署。

## 启动过程

按 `scripts/Start-Core.ps1` → 恢复 Seata/SkyWalking → `scripts/Start-Services.ps1` → `scripts/Start-Web.ps1` 执行，未使用 `-IncludeLegacyDemo`，历史 order/stock 示例保持关闭。

| 步骤 | 结果 |
| --- | --- |
| core compose | mysql-core / mysql-trade / redis / nacos 均 `healthy` |
| Seata、SkyWalking OAP/UI | 由既有容器 `docker start` 恢复，7091、8088 控制台 200 |
| 后端打包 + 四服务 | `sf-auth` 8081、`sf-fridge` 8082、`sf-recipe` 8083、`sf-gateway` 8080 全部 `actuator/health` = UP |
| Nacos | `SMART_FRIDGE` 分组注册 4 个服务，符合日常运行范围 |
| 菜谱数据 | 启动时 Flyway V2 在主库执行，`recipe_db.recipe` = 18 条 |
| Web 容器 | `sf-web` 3030 托管当前 release，`/api` 代理返回 401（网关已连通） |

第一次执行 `Start-Web.ps1` 失败：nginx 启动时解析固定 upstream `sf-gateway` 失败（`host not found in upstream`），网关容器尚未创建。该顺序问题不是缺陷，网关注册后重启 `sf-web` 即恢复，已在结论中记为启动顺序约束。

## 局域网可达性检查

- `Get-NetTCPConnection -LocalPort 3306/8848` 与 `curl http://10.66.46.139:3030` 均失败，容器端口只发布到回环地址；与运行手册 5.2 记录一致。
- 当前用户无管理员权限，`netsh interface portproxy` 与防火墙规则读取均被拒绝（`Enable-LanAccess.ps1` 不可用）。
- 防火墙现状：公用配置关闭、域配置启用（本机处于 10.66.0.0/16 网络）；实测宿主机监听后局域网可达，未再新增放行规则。

## 改动

- `scripts/preview-quiet-white.mjs`：新增 `PREVIEW_HOST`（默认 `127.0.0.1`，行为与之前一致），用于在无管理员权限时把同一 release 托管到 `0.0.0.0`。其余逻辑、路径白名单、代理行为未变。
- `docs/开发运行手册.md` 5.2：补充「宿主机静态服务」方案、判断条件与命令。
- `docs/开发状态.md`：运行地址补充局域网入口，修正原 3000/3030 行的说明。

## 验证命令与结果

```bash
curl -o /dev/null -w "%{http_code}" http://10.66.46.139:3000/                    # 200
curl -o /dev/null -w "%{http_code}" http://10.66.46.139:3000/main.dart.js         # 200
curl -o /dev/null -w "%{http_code}" http://10.66.46.139:3000/canvaskit/canvaskit.wasm  # 200
curl -o /dev/null -w "%{http_code}" http://10.66.46.139:3000/api/v1/recipes       # 401（未带令牌）
curl -X POST http://10.66.46.139:3000/api/v1/auth/login -d '{"identifier":"__lanprobe__","password":"invalid-pass"}'  # 401 账号或密码错误
```

登录探测使用不存在的账号，未创建数据，未输出令牌。

## 未完成 / 边界

- 宿主机监听进程是用户态进程，终端或会话结束后失效；长期运行仍需管理员执行 `Enable-LanAccess.ps1`（portproxy 3000→3030）。
- 没有用真实手机或其他电脑浏览器打开页面；局域网侧只做了 HTTP 层验证（首页、关键静态资源、登录鉴权），没有执行登录后业务写操作的界面验收。
- 本轮没有重跑后端自动化、Flutter 测试或接口验收矩阵。
- V2.0 隔离预览 18000/18080/18083 未启动；局域网入口直接使用当前 release 与主库 18 道菜谱，不依赖隔离 schema。
