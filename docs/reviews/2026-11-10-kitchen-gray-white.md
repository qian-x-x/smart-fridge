# V2.0.1 厨房灰白黑调整审查

日期：2026-11-10。用户反馈厨房过白，要求降低白色亮度并搭配灰白黑。结论：**代码审查及自动化通过，桌面/手机网页实际画面检查通过**；Android 仅构建及包校验通过，真机未验收。

## 范围与实现

- 原工作区未提交改动全部保留。根据上轮产物清单 SHA256 确认，本次只修改上轮 9 个正式源文件，新增 1 张参考图和 1 个画面检查脚本。上轮 ASCII 构建副本与旧 SHA256 一致，用它生成本次完整增量 diff；累计源码 diff 一并保存，未把历史改动当成本次新增。
- 厨房下柜/冰箱两侧高柜改为石墨灰，上柜与墙面改为中浅冷灰，台面深灰，地面中灰，冰箱为柔和的哑光灰白，窗框/拉手近黑。地面与台面拆分材质，避免一起被提亮。
- 曝光 0.88→0.78，环境贴图强度设为 0.55；降低环境光、主光与补光，提高冰箱粗糙度、降低反射。第一次实际检查发现下柜仍偏浅，进一步加深柜体纹理与台面，最终关门/展开状态均检查。
- 三维资源入口及所有模块引用统一升级 `quiet-white-v2.0.1`，避免旧材质缓存。核对本地 Three.js r180 支持 `Scene.environmentIntensity`，没有更换库或外部 CDN。
- 用内置 image_gen 编辑原厨房参考图，保留构图与物件，改为同一灰白黑配色。新文件 `apps/fridge-app/assets/images/kitchen-gray-white-v2.0.1.png`，1536×1024、1,772,065 字节；登录页和 Android 参考场景使用新图，原图留存。完整提示词、编辑模式及保存路径见 [生成记录](../design/ui-redesign-2026-11-10/厨房灰白黑生成记录.json)。Web 首页仍是真实几何渲染。

## 完整差异审查

- 审查 9 个修改源文件的全部增量、新脚本、新图片/资源注册及本轮累计源码 diff。权限、家庭数据隔离、库存/菜谱、HTTP 接口、请求代次、异步写入、错误重试、弹层输入隔离与门体状态逻辑均无本次变更；本轮未写入业务数据。
- 新增材质不会改变几何、拾取或库存同步；新图片已显式注册，图片语义已同步。检查脚本使用独立浏览器会话进入演示，不注册账号、不修改真实家庭。
- 首次测试日志使用了错误的相对重定向路径，命令没有启动，未计为通过。改为绝对路径并检查退出码后，分析、全量测试和 Web 构建重新完整执行通过。
- 最终 Web 的四个三维文件与源码逐字节同 SHA256，Web / APK 的新参考图均与源图片同 SHA256，依赖锁文件无差异。

## 本轮实际验证

| 验证 | 结果 |
| --- | --- |
| `dart analyze lib test` | 无问题，`dart-analyze.log` |
| `flutter test --no-pub --reporter expanded` | **95/95**，`flutter-tests.log` |
| `node --test scripts/tests/fridge3d.test.mjs` | **5/5**，`threejs-tests.log` |
| `flutter build web --release --no-pub` | 通过，`web-build.log` |
| `pwsh -File scripts/Build-Flutter.ps1 -SkipChecks -SkipWeb` | APK 构建通过，`android-build.log` |
| `node scripts/review-kitchen-tone.mjs` | **11/11**，最终 release、Edge 软件 WebGL，`browser-review.json` |
| APK CRC / 新图 SHA256 / `apksigner verify --print-certs` | 通过，仍为 Android Debug 模板签名 |
| JS 解析 / `git diff --check` / 锁文件零差异 | 通过 |

11 项浏览器检查包含新登录图正常加载；1440×1000 与 390×844 各自的新版本、库存同步、44 px 控制区及无重叠、关闭/全部展开状态；无 JS 运行异常或三维资源错误。实际截图逐张检查，手机滚动后模型及两行控制按钮均完整可见。此次聚焦配色，无需再次创建真实业务验收数据。

最终 APK：69,741,783 字节，SHA256 `946e45634cfff57045f7fd29475dc617c72f344cfbfbee0dd4413041cb45e7df`。本轮素材、源码、产物 SHA256、全部 diff 和日志见 [证据目录](evidence/2026-11-10-kitchen-tone/artifact-manifest.json)。固定桌面画布截图的平均编码灰度由 230.38 降为 152.91，仅为截图统计，不能视为屏幕亮度测量。

## 交付与边界

- 本机预览仍为 [http://127.0.0.1:18000](http://127.0.0.1:18000)，已使用最终新构建；原主服务没有被替换。未提交、推送或公开部署。
- [桌面关门](evidence/2026-11-10-kitchen-tone/home-desktop-closed.png)、[桌面展开](evidence/2026-11-10-kitchen-tone/home-desktop-open.png)、[手机关门](evidence/2026-11-10-kitchen-tone/home-mobile-closed.png)、[手机展开](evidence/2026-11-10-kitchen-tone/home-mobile-open.png)、[登录](evidence/2026-11-10-kitchen-tone/login-desktop.png)。
- 未执行：Android 真机、硬件 GPU、多浏览器、正式签名或压测。本次没有修改后端，未重跑 Maven 89 项或真实业务 48 项矩阵；上轮数字保留为历史结果，不能算作此次重新通过。
