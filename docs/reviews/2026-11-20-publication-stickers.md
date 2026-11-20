# 食材贴纸与冰箱清单发布审查

2026-11-20 以 `539f3cf` 为基线核对本次发布差异。发布范围包含 Flutter 用户端、三维冰箱和离线演示、151 张食材贴纸、库存与制作接口、Flyway V5/V6、接口契约、运行脚本及验收记录。推送目标为项目现有的 `origin/main`。

## 审查范围

- 检查批量入库与制作的家庭和冰箱范围、编辑角色、事务边界及并发请求重放。复核库存版本冲突后的刷新，以及响应不确定时的同一请求重试。
- 检查 Flyway 对旧常温库存及流水的分区归并、已有计量单位与别名的菜谱匹配，以及前端清单筛选和区间边界。复核 Web 场景通信的消息来源和库存版本。
- 核对待发布文本、测试凭据、素材与验收截图。25 张验收截图来自演示或测试流程，151 张贴纸为最大边长 240 像素的透明 WebP。本机配置、数据库与构建目录由 Git 忽略。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `dart analyze lib test`、`flutter test --no-pub --reporter expanded` | 静态分析无问题，105 项通过 |
| 在 `backend` 运行 `mvn -o -B test` | 95 项通过 |
| `node --test scripts/tests/fridge3d.test.mjs` | 11 项通过 |
| `node scripts/review-frontend-demo.mjs`，将 `DEMO_REVIEW_DIR` 指到本轮临时目录 | Edge 实际离线演示 126 项通过 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output build/commit-web-check` | 构建通过。Flutter 主程序、三维页面、贴纸模块、CanvasKit、本地 Roboto 和 151 张贴纸与运行中的预览构建 SHA-256 一致 |
| OpenAPI 引用、菜谱目录、脚本语法及 Compose 配置 | 161 处引用有效，18 道菜谱一致，本轮涉及的预览及验收脚本语法正常，core/full Compose 配置通过 |

本次复核了此前 18110 局域网预览的 20 项实际端到端结果，真实 MySQL 的制作和权限验证记录见 [局域网复核](2026-11-20-fridge-lan-current.md)。本轮重新执行的是上表中的自动化、离线浏览器和构建检查。真实家庭业务全量验收、实体手机和 Android 真机验收待执行。
