# 界面精简、储存区与镜头审查

本记录对应分区更正前的工作区。当前分区与本机预览见 [变温恢复及常温移除审查](2026-11-19-fridge-variable.md)。

日期为 2026-11-19，基线为 `539f3cf`。审查覆盖正式 Flutter 应用、Three.js 厨房、独立离线演示、冰箱服务、OpenAPI、迁移和回归脚本的完整差异。

## 审查与处理

- 登录、注册、冰箱、菜谱和家庭页面删除宣传语和重复说明。库存标题直接显示当前分区，保留操作、计数、校验和错误反馈。手机将场景放在库存统计上方，390 像素宽度下可见完整开合控件。
- 厨房只保留居中的双门冰箱、冷冻抽屉和两侧短台面，右侧台面承载常温库存。Web 镜头于 400 毫秒内插值位置和观察点，重复点击默认冷藏也能启动。连续切换从当前画面接续，隐藏场景恢复后继续推进。Android 使用同一场景渲染的参考图和 400 毫秒平移缩放。各端遵循减少动态效果设置。
- 三个储存分区及四个默认容器由后端初始化。Flyway V5 以各自冰箱 ID 查找冷藏区，归并旧变温食材和操作流水的两个位置引用。原有数量、到期日、状态和历史操作标识保留。已移除的容器引用置空，涉及位置变更的食材递增版本，旧表单会按既有冲突机制处理。
- 权限与数据隔离复核涵盖家庭查询、食材写入和历史撤销与恢复。通用食材接口仍按家庭与分区 ID 做归属校验。Web 场景按家庭和冰箱更新实例，继续校验消息来源；Flutter 发起的镜头切换由界面消费一次。离线演示同时迁移各家庭的库存和撤销快照，跨标签页的旧快照保护继续生效。
- 首次并行测试遇到 Windows 内存不足，改用顺序和受限堆配置重跑。首轮软件渲染因逐帧限速拉长过渡，改用帧时间推进并减少静止时重绘和阴影开销。浏览器窄屏检查等待 Flutter 重排完成后采样。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `mvn -o -B '-DargLine=-Xmx288m -XX:MaxMetaspaceSize=176m -XX:+UseSerialGC -XX:ActiveProcessorCount=2' test` | 90 项通过，覆盖空库和已有库升级 |
| `dart analyze lib test`、`flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，94 项通过，含参考图的中间帧和 400 毫秒结束状态 |
| `node --test scripts/tests/fridge3d.test.mjs` | 7 项通过，覆盖三个分区、开合、镜头路径和中途改选 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output $previewBuild` | 构建成功，产物在独立 Web 预览目录 |
| `node "$env:TEMP/xiaoyi-fridge-focus-release.mjs"` | 实际 release 的 Edge 软件渲染 12 项通过。1440、390、320 像素布局通过，六次分区切换均采到 3–6 个中间帧，实际采样完成时间为 411–628 毫秒 |
| `node scripts/review-frontend-demo.mjs` | `file://` 演示 116 项通过，含读取旧变温数据后实际撤销、安全重试和无网络请求 |
| `python "$env:TEMP/xiaoyi-check-mysql-zone.py"` | 使用本机 MySQL 8.0.39 临时 schema，测试 V4 旧数据、V5 回滚与提交、两个家庭的独立位置、数量、版本和重复执行，测试结束后删除临时 schema |
| `git diff --check` 与 OpenAPI 引用检查 | 差异检查通过，29 条路径、156 个内部引用和三区枚举通过 |

[桌面场景](evidence/2026-11-19-fridge-focus/desktop-overview.png) · [手机冷藏近景](evidence/2026-11-19-fridge-focus/mobile-fresh.png) · [Web 验证结果](evidence/2026-11-19-fridge-focus/release-tests.json) · [离线演示结果](evidence/2026-11-19-fridge-focus/offline-review.json)

本轮通过代码审查、自动化、实际 Web 演示交互及隔离 MySQL 迁移验证。本机演示入口为 [127.0.0.1:18110](http://127.0.0.1:18110/)。主运行库升级后的真实账号端到端验收、Android 真机和硬件 GPU 验收仍待执行。
