# 冷冻与变温抽屉俯视审查

俯视取景的后续调整见 [抽屉四边完整取景审查](2026-11-19-fridge-drawer-frame.md)。

2026-11-19 复核本轮 Web 三维场景、Flutter 图片模式、离线演示和回归脚本的完整差异。上一阶段分区及迁移结果见 [变温恢复及常温移除审查](2026-11-19-fridge-variable.md)。

## 审查与处理

- 冷冻与变温使用垂直向下的镜头，抽屉拉出后以内腔填满场景。冷冻的上篮置于后部，从上方可同时看到前部下篮和后部上篮。调整上篮食材的间距并补齐侧面内衬，避免窄屏裁掉边缘食材。冷藏沿用双门、搁板和正面取景。
- 分区按钮、场景按钮、模型点击和键盘进入同一套抽屉选择状态。选择冷冻或变温后只打开选中的抽屉，关闭其他抽屉及左右门。重复点击当前场景抽屉控制可关闭。概览仍可查看全部开合结构。
- 400 毫秒镜头过渡使用连续插值，快速改选从当时已渲染的姿态接续。镜头垂直时使用随镜头变化的上方向，俯视时禁用自由旋转。Android 增加两个俯视参考画面并使用 400 毫秒淡入淡出。离线演示用当前家庭库存绘制铺满场景的俯视层，俯视时停用其下的模型按钮，保留可见控件。
- 核对家庭切换后重新创建场景、消息来源校验以及旧相机过渡被最新指令替换。抽屉状态只作用于当前客户端视图。库存、API、权限和数据库规则沿用上一阶段。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `node --test scripts/tests/fridge3d.test.mjs` | 8 项通过。验证垂直方向、柜体遮挡、两种抽屉互斥、400 毫秒插值及三个宽高比下各 12 个食材模型完整入镜 |
| `dart analyze lib test` 和 `flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，94 项通过。验证冷藏缩放、两种俯视参考图的中间状态及完成状态 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output $previewBuild` | 构建通过，本机预览已更新 |
| `node "$env:TEMP/xiaoyi-fridge-overhead-assets.mjs"` | 从实时场景生成 Android 俯视图，并在 284×352 与 948×502 的画布上检查完整食材布局 |
| `node "$env:TEMP/xiaoyi-fridge-overhead-release.mjs"` | Edge 实际 Web release 16 项通过。覆盖桌面和手机画面、点三维模型、关其他门和抽屉及途中改选。六次过渡各采到 3 至 12 个中间帧，软件渲染采样为 409 至 550 毫秒 |
| `node scripts/review-frontend-demo.mjs` | 离线浏览器 120 项通过。验证俯视层中间帧、内腔覆盖、三种宽度下的互斥状态和本地数据回归 |
| `git diff --check` 与 JavaScript 语法检查 | 通过 |

[桌面冷冻俯视](evidence/2026-11-19-fridge-overhead/desktop-freezer.png) · [手机变温俯视](evidence/2026-11-19-fridge-overhead/mobile-variable.png) · [Web 验证](evidence/2026-11-19-fridge-overhead/release-tests.json) · [离线验证](evidence/2026-11-19-fridge-overhead/offline-review.json)

代码审查、自动化和 [本机 Web 演示](http://127.0.0.1:18110/) 验证通过。真实账号完整端到端、Android 真机与硬件 GPU 验收仍待执行。后端和迁移验证结果见上一阶段记录。
