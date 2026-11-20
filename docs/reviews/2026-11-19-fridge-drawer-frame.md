# 冷冻与变温抽屉取景审查

2026-11-19 复核俯视取景、Android 参考图、离线演示和相关测试差异。交互与库存范围沿用 [上一阶段审查](2026-11-19-fridge-overhead.md)。

## 审查与处理

- Web 以抽屉外沿、前面板和把手确定取景范围。按当前画布宽高比计算镜头距离，四边和四角均在画面内，限制取景的一侧留有边距。用实际模型的投影边界检查选中抽屉与已关闭冰箱之间的遮挡及食材裁切。
- Android 重新截取两张俯视参考图并按比例完整显示。离线演示的俯视层在画布内留出边距，概览按钮位于抽屉轮廓上方。
- 核对 400 毫秒过渡、快速改选、门与抽屉互斥状态、冷藏双门，以及各家庭独立的场景与库存来源。本轮改动只作用于取景和参考图。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `node --test scripts/tests/fridge3d.test.mjs` | 8 项通过。以四种画布宽高比验证两个抽屉的完整轮廓、边距、垂直视角及各 12 个食材模型 |
| `dart analyze lib test` 和 `flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，94 项通过。检查俯视参考图完整显示和原有过渡 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output $previewBuild` | 构建通过，已更新独立本机预览 |
| `node "$env:TEMP/xiaoyi-fridge-frame-assets.mjs"` 和 `node "$env:TEMP/xiaoyi-fridge-frame-release.mjs"` | 真实 Three.js 画面核对了 284×352 和 948×502 画布。Edge 实际 Web release 16 项通过，覆盖 1440、390、320 像素布局、互斥开合及连续改选。六次过渡采到 4 至 10 个中间帧，软件渲染采样为 418 至 598 毫秒 |
| `node scripts/review-frontend-demo.mjs` | 126 项通过，包含三个视口宽度下两个抽屉的四边留白及原有数据回归 |
| `git diff --check` 和 JavaScript 语法检查 | 通过 |

[桌面冷冻](evidence/2026-11-19-fridge-drawer-frame/desktop-freezer.png) · [手机变温](evidence/2026-11-19-fridge-drawer-frame/mobile-variable.png) · [Web 验证](evidence/2026-11-19-fridge-drawer-frame/release-tests.json) · [离线验证](evidence/2026-11-19-fridge-drawer-frame/offline-review.json)

代码审查、自动化和 [本机 Web 演示](http://127.0.0.1:18110/) 已验证。真实账号完整端到端、Android 真机和硬件 GPU 验收仍待执行。
