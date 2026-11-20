# 冰箱贴纸格位审查

本轮复核了工作起点到当前的 Flutter、Web 场景、样式和回归用例完整差异。旧 Web 布局用网格的固有尺寸计算长图。在真实浏览器复现时，78 像素格位内的食用油图片高 246 像素，两张酱油瓶各高 215 像素。

- 食材图片现在在方形容器内等比缩放。浏览器依据场景投影计算各格的可用宽高，把浮动和悬停位移也限制在格内。Android 参考图以各层、各抽屉的实际显示范围分格。
- 变温和冷冻各默认 4×4。第 17 种食材入库后扩为 8×4，贴纸随格位缩小。冷藏双门共 6×4，单开一侧显示该侧 12 格。超过当前布局容量时可以翻页。
- 同分区同名食材合为一格，按份记录显示合计份量。份量或批次较多时绘制最多三层。不同单位的历史批次可叠放，数量按各自批次管理。生抽和老抽共用图源时分别占格。
- 贴纸点击使用同组中优先到期的可用批次。审核确认 Web 消息继续核对来源窗口和库存版本，布局计算仅使用当前家庭的库存数据。分页在库存减少后会自动回到可用页。

## 代码审查及自动化验证

| 本轮命令或检查 | 结果 |
| --- | --- |
| `dart analyze lib test` | 无问题 |
| `flutter test --no-pub --reporter expanded` | 100 项通过，新增同名堆叠、旧单位和 16 至 32 格回归 |
| `node --test scripts/tests/fridge3d.test.mjs` | 11 项通过，覆盖门侧、抽屉容量和悬停投影边界 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output build/sticker-grid-web` | 通过，核对后切至本机 18134 构建目录 |
| `flutter build apk --debug --no-pub` | 通过，APK 压缩结构及全部 151 张贴纸已核验。[APK 校验](evidence/2026-11-20-fridge-sticker-grid/android-build.json) |
| `git diff --check` 和本轮完整源代码差异核对 | 通过 |

## 本机真实环境端到端验收

`node build/sticker-local-preview/verify-grid.mjs` 在切换前使用 Edge 软件 WebGL、候选构建、真实网关和 V6 预览库完成 18 项检查。桌面与窄屏的 32 种满格画面均通过尺寸和重叠检查。桌面食用油的格内显示区域从默认密度的 63.5 像素缩小至 44.3 像素。第 33 种可翻页查看。脚本针对视口切换后场景重新挂载、弹层关闭及库存异步刷新重新等待渲染完成。[本轮浏览器结果](evidence/2026-11-20-fridge-sticker-grid/browser-validation.json)

[16 格抽屉](evidence/2026-11-20-fridge-sticker-grid/drawer-16-desktop.png) · [32 格抽屉](evidence/2026-11-20-fridge-sticker-grid/drawer-32-desktop.png) · [窄屏满格](evidence/2026-11-20-fridge-sticker-grid/drawer-32-mobile.png) · [双开门 24 格](evidence/2026-11-20-fridge-sticker-grid/fresh-24-desktop.png)

[本机 18134 新版](http://127.0.0.1:18134/?v=sticker-grid-v23) 已提供此次验收的构建，场景版本为 `fridge-sticker-grid-v2.3`。HTTP 内容哈希与构建文件一致，预览继续连接原有 V6 库和网关。[本机入口核对](evidence/2026-11-20-fridge-sticker-grid/local-preview-validation.json)

本轮范围为贴纸布局及其相关 Web 交互。Android 真机、硬件 WebGL 和独立后端测试套件本轮未重新验收。
