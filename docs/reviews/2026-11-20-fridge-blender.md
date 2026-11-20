# Blender 冰箱场景导入审查

2026-11-20 以 `77147c1` 为基线审查本轮完整差异，覆盖 Blender 源文件、GLB 导出、Three.js 场景装配、Flutter 桥接、四张参考图和验证脚本。

## 审查与修复

- 将用户提供的 [Blender 源文件](../design/realistic-fridge/fridge_scene.blend) 原样收录到项目。运行 GLB 保留原导出的 28 个网格节点及其位置，包括冰箱、双侧台面、灶具、墙和地板。后台导出脚本只在内存中切出三区内腔，并修正门板和抽屉面板的平面法线。Web 使用 Three.js 实时灯光和 GLB 基础材质参数，Blender 的灯光、相机和程序材质保存在源文件中。
- 按网格名称将门板、拉手、抽屉面板和把手凹槽分别绑定到四个开合部件，保留原有隔板、门架和抽屉篮筐。首次取景回归发现冷冻上篮后沿在宽屏俯视中边距不足，向前校正上篮并复测两种抽屉的完整边界。浏览器截图发现面板有不均匀的斜向高光，修正法线后复验并补充射线法线断言。以同一场景生成 Android 四个视角，按各视角投影校准食材格位。
- 核对同源和窗口来源校验、食材版本及当前家庭库存的处理。GLB 是不含库存的同源静态资源。场景就绪后，Flutter 发送当前分区、输入状态和库存，贴纸点选仍校验库存版本和当前食材。真实接口和数据权限沿用现有业务流程。
- GLB 下载有超时兜底。离开页面时取消下载，迟到的解析结果不会启动旧场景。模型请求失败时显示原位重试入口，重试成功后恢复交互。Three.js 加载器与核心同为 r180，本地提供所需模块。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| Blender 5.3 运行 `scripts/Export-FridgeScene.py` | 导出通过，GLB 为 295,012 字节。源文件副本与原文件 SHA-256 一致，运行资产无外部缓冲区或图片依赖 |
| `node --test scripts/tests/fridge3d.test.mjs` | 12 项通过，包含 GLB 加载、部件绑定、内腔、面板法线、俯视取景及贴纸格位 |
| `dart analyze lib test`、`flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，105 项通过 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output build/blender-fridge-web` | 构建通过。GLB、加载器和四张参考图与源文件逐字节核对。18135 返回的 GLB 为 `model/gltf-binary` |
| `node build/blender-scene/verify-release.mjs` | 本机 Edge 实际运行 Web release，17 项通过。覆盖 1440、390、320 像素视口、门板点选、触摸抽屉、快速改选、贴纸点选、来源校验及加载失败重试。[浏览器结果](evidence/2026-11-20-fridge-blender/browser-validation.json) |
| `flutter build apk --debug --no-pub` | 构建通过。APK 压缩校验及四张参考图逐字节核对通过。[构建校验](evidence/2026-11-20-fridge-blender/android-build.json) |
| `git diff --check`、JavaScript 和 Python 语法检查 | 通过 |

[本机 Web 预览](http://127.0.0.1:18135/) · [桌面首页](evidence/2026-11-20-fridge-blender/desktop.png) · [手机尺寸冷冻俯视](evidence/2026-11-20-fridge-blender/mobile-freezer.png)

代码审查及自动化通过。本轮实际浏览器验收使用演示库存与 SwiftShader。真实账号全量业务、硬件 WebGL 和 Android 真机待验。
