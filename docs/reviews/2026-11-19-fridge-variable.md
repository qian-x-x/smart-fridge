# 冰箱变温恢复及常温移除审查

抽屉视角的后续调整见 [冷冻与变温抽屉俯视审查](2026-11-19-fridge-overhead.md)。

2026-11-19 以 `539f3cf` 和上一轮界面精简的工作区为基线，复核正式 Flutter 应用、Three.js 场景、独立离线演示、默认冰箱、迁移、OpenAPI 和回归脚本的完整差异。

## 审查与处理

- 分区统一为冷藏、变温、冷冻。恢复变温按钮、中部抽屉、食材筛选和表单选项。默认创建五个容器，变温包含上层和抽屉。OpenAPI 保留 `VARIABLE`，移除 `PANTRY` 和仅用于原常温储物筐的 `BASKET` 类型。通用分区 ID 和食材接口路径沿用现有契约。
- Flyway V5 将原常温食材及流水两端的位置归入各自冰箱的冷藏区，清空被移除的储物筐引用，并递增受影响食材的版本。已有变温区和容器的 ID、库存及流水保留。核对家庭权限、分区归属、编辑版本校验和历史撤销与恢复，避免位置迁移跨越家庭。客户端可读旧版响应中的常温数据，离线演示同步迁移本地库存和撤销快照。
- 厨房场景保留居中的冰箱、两侧短台面、墙面和地面。变温按钮聚焦中部抽屉，开合状态独立。镜头按 400 毫秒插值，快速改选从当前画面接续。核对 Flutter 消息来源检查、家庭切换后的场景隔离和暂停渲染后的恢复，刷新了 Android 参考图。
- 主库迁移历史仍为 V4。隔离 MySQL 在 V5 最后的删除语句注入失败，确认此前食材、流水、容器与分区变化全部回滚。清理测试触发器、修复隔离库迁移历史后重试成功，再执行时无变更。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `mvn -o -B '-DargLine=-Xmx288m -XX:MaxMetaspaceSize=176m -XX:+UseSerialGC -XX:ActiveProcessorCount=2' clean test` | 90 项通过。包含 API 创建及查询三区、食材移动、两个冰箱从 V4 升级 |
| `dart analyze lib test` 和 `flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，94 项通过。验证旧版 API 响应、变温容器、参考图过渡中间帧 |
| `node --test scripts/tests/fridge3d.test.mjs` | 7 项通过。覆盖三区状态、独立开合、食材位置、400 毫秒轨迹和改选起点 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output $previewBuild` | 构建成功，产物运行于独立本机预览 |
| `node "$env:TEMP/xiaoyi-fridge-zones-release.mjs"` | Web release 在 Edge 软件渲染下 14 项通过。1440、390、320 像素布局通过。六次点击各采到 2 至 10 个镜头中间帧，观测完成时间为 433 至 520 毫秒。另验证直接开变温抽屉及过渡中改选 |
| `node scripts/review-frontend-demo.mjs` | 离线演示 134 项通过。覆盖两种宽度的 16 种开合组合、变温筛选与过渡、旧常温快照撤销及存储失败恢复 |
| `python "$env:TEMP/xiaoyi-check-mysql-zones.py"` | MySQL 8.0.39 临时 schema 使用 Flyway 先迁移到 V4，再验证 V5 的失败回滚、重试、旧数据及重复执行。验证结束后移除测试 schema |
| `git diff --check`、脚本语法和 OpenAPI 检查 | 通过。29 条路径和 156 个内部引用可解析，三区及容器枚举正确，离线演示六张嵌图与基线一致 |

[桌面概览](evidence/2026-11-19-fridge-variable/desktop-overview.png) · [手机变温近景](evidence/2026-11-19-fridge-variable/mobile-variable.png) · [Web 验证结果](evidence/2026-11-19-fridge-variable/release-tests.json) · [离线演示结果](evidence/2026-11-19-fridge-variable/offline-review.json)

代码审查、自动化、独立数据库升级和 [本机 Web 演示](http://127.0.0.1:18110/) 验证通过。现有 8080 至 8085 服务健康检查均为 UP，3030 返回 HTTP 200。运行中的主库升级、真实账号的完整端到端、Android 真机及硬件 GPU 验收仍待执行。
