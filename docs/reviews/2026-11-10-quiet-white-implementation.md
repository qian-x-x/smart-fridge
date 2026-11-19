# V2.0 静白全景与家常菜谱 · 分阶段审查

日期：2026-11-10。用户已选 A「静白全景」并授权重新生成菜谱图、扩充家常菜谱。提交基线 `60a0077`；本轮开始前已有 D0 设计包与状态文档差异，全部保留。

后续厨房过白反馈已通过 [V2.0.1 灰白黑调整审查](2026-11-10-kitchen-gray-white.md)。下方 D1–D4 的截图、SHA256 与计数对应首次 V2.0.0 实施时点；当前构建和最新画面以 V2.0.1 证据为准。

## D1 颜色、按钮、导航与登录基础

结论：代码审查和本轮自动化通过，进入 D2。真实浏览器、完整 Web 构建与 Android 尚未在此阶段执行。

- 范围：完整累计工作区 diff（含 D0 设计包）及新增素材；本阶段正式代码为 Flutter 主题、按钮反馈、HomeShell、AuthScaffold、AppBrand、pubspec 资源与 Web/PWA 颜色。
- 黑白/浅冷灰主题替换暖橙；主按钮 12 px 圆角、悬停/按压/焦点/禁用状态；按压改为 1 px 下移，保留原命中区和减少动态效果。
- 窄导航选中为黑底白字，手机有品牌/家庭顶栏，家庭名称限制宽度；登录图在左、表单在右。使用用户选定的厨房参考图作为认证页素材，正式冰箱仍使用真实三维。
- 权限、家庭数据、会话与路由分支逻辑未改；导航仍保留页面及三维实例，SceneInputScope 与原弹层输入隔离保留。未改变任何接口。
- 发现本机镜像环境使默认 `flutter test` 的隐式 pub get 更新了锁文件。已恢复本轮自动产生的 lock 改动，指定官方源并执行 `flutter pub get --enforce-lockfile`，确认 `git diff --exit-code -- apps/fridge-app/pubspec.lock` 无差异。后续测试/构建使用 `--no-pub`，不把依赖升级混入 UI 改版。

本轮实际命令与结果：

```powershell
# apps/fridge-app
$env:PUB_HOSTED_URL = 'https://pub.dev'
flutter pub get --enforce-lockfile
dart analyze lib test
flutter test --no-pub --reporter expanded
# 仓库根
git diff --check
git diff --exit-code -- apps/fridge-app/pubspec.lock
```

- 静态分析无问题，锁定原依赖后 Flutter **92/92** 通过，日志见 `evidence/2026-11-10-quiet-white/d1-flutter-tests.log`。
- 首次日志重定向路径错误导致命令未启动；已改为项目绝对路径并重跑。此失败不计作测试通过。
- `git diff --check` 通过，锁文件无差异。Git 的 CRLF 提示不是空白错误。
- 当前菜谱图生成是 D3 素材准备；尚未据此宣称菜谱目录或新图片集已接入验收。

待后续验收：手机软键盘/长名称/真实浏览器、Three.js 冷调材质、完整食材/菜谱/家庭路径、Android 真机。

## D2 首页与三维厨房

结论：完整累计代码差异审查及自动化通过，进入 D3；真实 GPU/浏览器触控尚待 D4，未以几何测试替代浏览器验收。

- 首页调整为 A 的标题/摘要、大场景、右侧分区清单和底部菜谱入口；临期统计排除已过期，另列已过期数。临期仍读取 `isExpiring`，未把样稿三天阈值写入生产。
- 手机新增是有独立布局高度的底部操作区，不悬浮覆盖模型；所有新增/详情仍调用原有表单、版本与控制器。清理过期在只读/演示时禁用，后端权限规则不变。
- Three.js 仅调整材质、纹理与冷白光照，保留门、抽屉、分区、真实库存与消息来源检查。控制栏移到画布外的网格行，resize 按画布实际尺寸计算，避免手机控制按钮覆盖模型。所有资源版本统一为 `quiet-white-v2.0.0`。
- 审查重点：未改会话与家庭请求代次、未用筛选结果覆盖完整场景、未更改跨页暂停/恢复和弹层输入隔离、接口零变更。新增/使用/移动/丢弃继续走原服务端路径。
- 原交互测试只更新新增按钮文案为“新增食材”，保留全部草稿、错误恢复、只读和实际写入断言，没有删除失败断言。

本轮实际：`dart analyze lib test` 无问题；`flutter test --no-pub --reporter expanded` **92/92**；`node --test scripts/tests/fridge3d.test.mjs` **5/5**；`git diff --check` 通过。Flutter 日志：`evidence/2026-11-10-quiet-white/d2-flutter-tests.log`。

待后续：真实浏览器画布/控制栏尺寸、全部开合组合、家庭切换与跨页状态、软键盘、Android 实机。菜谱仍待 D3 接入。

## D3 十八道家常菜与独立图片

结论：代码审查、菜谱模块测试、Flutter 回归与素材检查通过，进入 D4 完整构建及本地浏览器验收；此时还没有宣称真实 MySQL / 运行中服务已升级。

- 原 6 道菜保留 ID/名称/原料记录，V2 Flyway 追加 12 道及原料，更新旧步骤说明；V1 迁移不改。全目录 18 道、100 条原料记录，含明确数量/单位、可选原料和 4–6 步做法。能量字段保留兼容，新增 0 表示未估算，UI 不展示能量。
- 18 道各调用一次内置 image_gen，逐张检查主体与菜名；原始 PNG 全部保存在设计包 `recipe-originals/`，应用使用不裁剪、不调整构图的 JPEG 90 编码。原图共 44,431,920 字节，应用图片共 5,712,025 字节；生成提示词、原始路径与应用路径见 `菜谱图片生成记录.json`。
- 图片按精确菜名映射，不按序号取模或泛关键词复用；未知菜谱使用中性图标。前端改为延迟构建的 1/2/3 列网格，保留现有库存匹配、搜索、筛选、权限及做饭确认逻辑。
- 共享 JSON 作为目录核对来源，编译后的演示目录由 `scripts/sync-recipe-catalog.mjs` 生成；真实登录仍只读取 API，不合并演示菜谱。生成目录校验通过，后端接口逐字段与 JSON 对比通过。
- 首次目录一致性测试因 MockResponse 默认字符串编码而误读中文，改为从原始 UTF-8 字节解析；业务 JSON 未损坏。首次 Flutter 全量回归出现演示目录新增文件 I/O 导致的路由等待不稳定，改为编译目录，使切换/登出不等待资产 I/O；保留并重跑原路由私有状态断言。

本轮实际命令：

```powershell
# backend
mvn -o -q -pl recipe-service -am test
# apps/fridge-app
dart analyze lib test
flutter test --no-pub --reporter expanded
# 仓库根
node scripts/sync-recipe-catalog.mjs --check
git diff --check
```

- recipe-service **6/6**（API 5 + 升级兼容 1），上游 common-core 另 1 项通过；日志与 Surefire 报告已检查。
- 升级测试从 V1 的 6 道 + 自定义第 900 道开始，V2 后为 19 道，保留旧 ID、旧原料行和自定义行，再运行迁移不会重复新增。
- Flutter **94/94**，新增覆盖 18 道完整目录、18 个独立已打包图片与未知菜谱占位；静态分析无问题，生成目录一致、Git 空白检查通过。
- 日志：`evidence/2026-11-10-quiet-white/d3-flutter-tests.log`、`d3-recipe-tests.log`。失败过程的原因如上，最终结果为修正后重新执行，不沿用先前通过。

待 D4：完整构建、全部后端回归、真实 MySQL 迁移与接口、实际 Web 图片和交互、Android 编译/真机边界。

## D4 完整差异审查、构建与本机实际验收

结论：**本轮代码审查及自动化验证通过，本机 Web 实际接口与浏览器验收通过**。D1–D4 实施完成；Android 仅构建和包校验通过，真机验收仍未执行。不把软件 WebGL、隔离数据库或历史验收当成目标设备/原运行环境已通过。

### 审查范围与发现

- 对照 `60a0077` 审查累计工作区差异，含新增文件；正式源码涉及 34 个文本文件和 19 个新增应用图片文件。D0 设计包、18 张生成原图、生成记录、实施规格、脚本、测试及证据一并核对。正式源码完整 diff 保存在 `evidence/2026-11-10-quiet-white/implementation-source.diff`；素材和源码 SHA256 见同目录 `artifact-manifest.json`。
- 权限与隔离：未改变 Gateway、身份/家庭权限实现或 API 契约；真实登录目录只取 API，演示目录只供演示会话。实际验证跨家庭查询返回 404（隐藏不可访问家庭是否存在）、VIEWER 新增返回 403，重新登录 VIEWER 后“新增食材”禁用。预览服务只监听 `127.0.0.1`。
- 异步与失败恢复：保留家庭请求代次、会话清理、版本冲突、草稿、写入锁定及 SceneInputScope。菜谱做饭完成后的关闭动作检查原详情路由仍为当前路由，防止等待动画期间用户关闭详情后误退其他页。图片加载失败显示中性图标，API 失败仍显示重试，不把演示菜谱混进失败的真实请求。
- 发现可选原料因为不在“缺少必需原料”集合中而被画为绿色勾号。已改为中性空心圆，并补上“可选原料”语义；必需原料仍区分“已备食材/缺少食材”。新增组件回归并在实际麻婆豆腐详情检查两项可选原料。
- 发现冷白材质在实际画面中过曝，已降低曝光与补光并调整石材、墙面、柜门颜色；最终桌面、手机截图检查通过。3D 控制区独立于画布，44 px 命中区域，手机采用两行按钮，32 个开合组合全部通过。
- 本机 Windows 中文工作区使 Flutter Android AOT 路径失败；仅建 junction 仍会解析回中文原路径。`Build-Flutter.ps1` 改为真实 ASCII 临时源码副本，固定现有锁文件，所有子命令检查退出码，构建后复制 APK 回工作区，保留副本供检查。未递归删除工作区，没有把构建成功等同于真机通过。
- 预览辅助脚本的静态文件根目录分别受限，拒绝编码路径逃逸；API 即使收到 absolute-form URL 也固定代理到配置的本机网关。实际边界检查 6/6：release、图集、两种路径逃逸、缺失图片、固定 API 目标。

### 本轮实际验证

| 层次 | 本轮结果 | 证据与边界 |
| --- | --- | --- |
| Flutter 静态分析 | 无问题 | `dart analyze lib test`，未升级依赖 |
| Flutter 全量回归 | **95/95** | `final-flutter-tests.log`；包括原业务回归、18 图目录、未知菜谱占位、可选原料显示 |
| Maven 全模块测试 | **89/89**，无失败/错误/跳过 | auth-family 27、common 1、fridge 44、gateway 11、recipe 6；`maven-all-tests.log` 与本轮 Surefire XML |
| Three.js 结构与状态 | **5/5** | 独立门/抽屉、层级、真实库存清空与纵屏视距 |
| Web release | 通过 | `web-build.log`；最终源码构建，18 张打包 JPG 与源码逐一同 SHA256 |
| Android release 编译 | 通过 | `android-build.log`；最终 APK 69,739,648 字节，ZIP CRC 及 18 图逐字节核对通过 |
| APK 签名校验 | 通过，模板 **Android Debug** | `apksigner verify --print-certs`；不代表正式分发签名 |
| 真实 MySQL 菜谱 | 18 道 / 100 条原料；无身份 401 | 新 schema `recipe_ui_20261110_012654`，Flyway V1→V2；`mysql-recipe-catalog.json` |
| 实际浏览器与业务 | **48/48** | `browser-acceptance.json`；Edge、1440×1000 / 390×844，实际 release、实际网关与服务 |
| 预览服务边界 | **6/6** | `preview-boundary-checks.json` |
| 目录/脚本/差异 | 通过 | 18 道 JSON→Dart 一致；3 个 Node、2 个 PowerShell 脚本解析通过；`git diff --check`、锁文件零差异 |

48 项浏览器检查包括：真实 API 18 道及菜名/步骤一致、跨家庭拒绝、只读写拒绝、场景同步 8 项真实库存、桌面和手机各 16 种门/抽屉状态、控制区不遮挡且按钮足够高、搜索与新菜详情、可选原料语义、实际网格逐张加载全部 18 图、真实做饭恰好一条记录、登出后 VIEWER 登录与禁用新增、无 JS 运行异常及失败资源。截图覆盖登录、首页、菜谱、详情、做饭确认和家庭页，并检查完整 18 图总览。

关键复验命令（在相应项目目录执行）：

```powershell
# apps/fridge-app
dart analyze lib test
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub
# backend
mvn -o -q test
mvn -o -q -pl recipe-service -am package -DskipTests
# 仓库根（测试及 Web 已分别执行，因此 Android 这次跳过重复步骤）
pwsh -NoProfile -File scripts/Build-Flutter.ps1 -SkipChecks -SkipWeb
node scripts/sync-recipe-catalog.mjs --check
node --test scripts/tests/fridge3d.test.mjs
pwsh -NoProfile -File scripts/Start-QuietWhiteAcceptance.ps1
node scripts/preview-quiet-white.mjs
node scripts/ui-acceptance-quiet-white.mjs
git diff --check
git diff --exit-code -- apps/fridge-app/pubspec.lock
```

最终 APK：`apps/fridge-app/build/app/outputs/flutter-apk/app-release.apk`。SHA256：`d9289aa13134862565e835b73a8d4bfff315c68378ed391518bcc67d532355ac`。所有 18 张应用图为 1254×1254，共 5,712,025 字节；生成原图共 44,431,920 字节。完整提示词、内置 image_gen 模式、原图与应用文件位置保存在设计包 `菜谱图片生成记录.json`。

### 运行边界、失败记录与未执行项

- 实际可预览 **http://127.0.0.1:18000**，API 走隔离网关 18080 与新菜谱服务 18083；后两者是带任务归属标签的本机验收容器。复用现有 auth/fridge，但所有写入都在新建验收账号、家庭与冰箱内，不修改已有用户家庭。
- 原 `sf-web` / `sf-recipe` 主服务没有被重启或替换；旧入口 3000/3030 和 8083 不能视为已升级。正式源码已含 V2 迁移，下次按常规更新该服务时才会升级原菜谱库。这里没有公开部署、提交或推送。
- 自动验收辅助脚本先后修正过工作区创建缺少 requestId、UTC 日期导致的时区偏移、手机滚动被三维画布接收、跨家庭误期望 403 而实际契约为 404，以及 Flutter Web 把语义写入 textContent 而非 aria-label 的定位差异。修正的是辅助脚本，未放宽产品权限；最终完整 48 项重新执行通过。
- `ui-failure.png` / `ui-debug.json` 保留辅助脚本修正前现场，不是最终验收截图。较早的 44 项通过不能替代最终 48 项；最终 JSON 为本轮末次完整结果。
- 未执行：Android 真机联网/触控/软键盘、正式签名分发、硬件 GPU 和多浏览器兼容、持续压测、原主菜谱数据库的就地迁移/重启与外部部署。软件 WebGL 检查不能代替以上项目；历史 223 项真实接口矩阵与真实追踪本轮未全部重跑。

预览、素材与构建使用说明见 [实施与预览](../design/ui-redesign-2026-11-10/实施与预览.md)。
