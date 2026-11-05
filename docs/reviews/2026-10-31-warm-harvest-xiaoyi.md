# 暖橙食集与小易冰箱阶段审查

日期：2026-10-31。用户已选择 C「暖橙食集」并授权实现，产品名称改为「小易冰箱」，寓意「查食材，看菜谱，都容易」。

结论：本轮前端代码审查与自动化验证通过；本地真实 Gateway 的桌面/手机浏览器关键路径验收通过。Android 安装包构建通过，尚未进行 Android 真机验收或正式签名。本次完成 UI 与品牌阶段，操作时间线和撤销/恢复仍为后续独立业务阶段。未提交、推送或部署。

## 审查范围与差异边界

- Flutter：启动、登录、注册、导航壳、冰箱首页、菜谱、家庭与设置、成员面板、食材查询/新增/详情、主题、按钮反馈、字体与品牌资源。
- WebGL：厨房/冰箱配色、静态模块版本、iframe 消息来源、输入暂停、隐藏分支生命周期与库存同步。
- Vue：登录、导航、看板、菜谱、库存、订单、图表生命周期、演示能力标记和响应式样式。
- 平台：Web 标题/manifest/favicon、Android 安装名称/图标与 Windows Kotlin 编译配置、OFL 字体来源及许可证。
- 复查当前完整工作区 diff，使用实施前文件快照区分既有审查修复与本次 UI 增量。既有业务修复保留；`backend/`、`contracts/`、`infra/` 的完整 diff 片段前后 SHA256 相同，抽查的 21 个应用/数据/领域/会话文件内容未变化。没有随视觉重构修改请求模型、API 路径、家庭角色规则或服务端接口。
- 证据：[源文件审计](evidence/2026-10-31-warm-harvest/source-audit.json)、[实施前后增量 diff](evidence/2026-10-31-warm-harvest/incremental-source.diff)。快照之前已建立的品牌常量、按钮和分支容器另按最终全文复查；新增退出保护、资源、测试及 Android 配置也纳入审查，不能仅依靠该文本 diff 判断全部范围。

完整业务差异的既有审查见 [前一轮全仓审查](2026-10-31-full-code-api-audit.md)。其中 Java 47 项与 Gateway 190 个断言属于前一轮结果，本轮没有重新执行这两套完整测试，不能算作本轮通过数量。

## 实现与审查发现

| 关注点 | 处理及最终结果 |
| --- | --- |
| 品牌与视觉 | 集中定义「小易冰箱」和口号；奶油底、陶土橙、暖木、圆角卡片与胶囊按钮；用户端和运营端统一。技术包名保留以兼容既有安装/工程配置。 |
| 切页重建三维场景、丢失查询 | 使用保留分支的导航壳；切页保留各页查询/滚动与 iframe，新增淡入/轻位移动画；非活动分支停止 ticker、焦点和模型输入/渲染循环。注销后分支销毁，私人查询不带入新会话。 |
| 弹层与三维抢输入 | 延续根导航弹层；父级控制输入，JS 同时暂停渲染；恢复时不会启动已失败场景。iframe 校验同源及 source，隐藏时忽略分区回传，销毁时取消订阅并移至 about:blank。 |
| 未保存表单被关闭 | 新增 FormExitGuard：实时读取是否修改/提交状态，确认继续编辑或放弃；覆盖同一帧输入后立即关闭。仅聚焦、选中文字不算修改；禁用拖拽关闭新增表单。 |
| 食材使用量与重复写入 | 数量可加减及手填，校验有限值、库存上限、最小 0.001 和原始文本最多 3 位小数，拒绝 1.000000001 等精度绕过；零库存禁用使用。保留当前 version；提交中锁定并防重复。丢弃显示具体对象和二次确认，不承诺未实现的撤销。 |
| 搜索弹层桌面拖拽影响操作 | 桌面改为固定高度双栏及独立滚动，手机保留纵向列表；已有迟到请求/家庭隔离测试继续通过。 |
| 权限和家庭隔离 | 新 UI 根据现有真实角色禁用写入口并说明原因；家庭切换仍使用业务控制器的请求隔离。真实 5 → 0 → 5 库存复验、VIEWER 写接口 403 与只读界面复验通过。 |
| 菜谱与运营演示误导 | 菜谱匹配和详情继续来自现有数据，照片按菜名匹配，其他使用图标；空筛选仍能清除。运营端显式标记示例数据；搜索/状态/日期筛选实际过滤演示行，列表统计按演示行计算；未接入的编辑/交易/导出维持说明。 |
| 字体加载后部分中文按钮缺字 | 内置 OFL 授权的衍生 Xiaoyi UI 常用中文字库，并在按钮、导航标签和筛选标签显式继承字体。独立新浏览器上下文最终截图中文字正常，本轮最终采集未请求远程 Noto Sans；生僻字/彩色 emoji 仍可能使用系统或引擎回退。 |
| Windows Android 构建失败 | 中文目录直接构建出现 app.dill 路径异常；ASCII 副本首次又遇 Kotlin 跨盘增量缓存。关闭 Kotlin 增量并用 in-process 编译，使用原工作区的 lock/package 配置构建最终物理副本；93 项源码/资源/平台配置哈希一致，未升级主工作区依赖。 |

按钮保留 Material/Element 的语义、焦点、禁用状态及命中区域；悬停、按下缩放和提交反馈统一，系统减少动态效果设置下关闭或缩短相关动画。复制邀请码实际访问剪贴板，并提供成功/失败提示。

## 本轮自动化与构建

以下命令在最终功能修改后执行，日志位于 [证据目录](evidence/2026-10-31-warm-harvest/)；[自动检查摘要](evidence/2026-10-31-warm-harvest/automatic-checks.json) 中退出码均为 0。

| 工作目录 | 命令 | 本轮结果 |
| --- | --- | --- |
| apps/fridge-app | `dart analyze lib test` | 无问题 |
| apps/fridge-app | `flutter test --no-pub --reporter expanded` | 72 项通过 |
| apps/fridge-app | `flutter build web --release --no-pub` | 成功 |
| 仓库根 | `node --test scripts/tests/fridge3d.test.mjs` | 4 项通过 |
| apps/admin-web | `npm run build` | TypeScript 检查与 Vite 生产构建成功；仍有大于 500 kB 的 chunk 提示 |
| ASCII 源码副本 | `flutter build apk --release --no-pub` | 最终成功，58.9 MB；模板 debug 签名 |
| 仓库根 | `git diff --check` | 通过 |

新增/扩展回归覆盖分支场景与查询保留、隐藏场景禁用、注销缓存清除、草稿继续/放弃与立即关闭、未修改字段聚焦、分数用量与非法精度、丢弃取消/确认。既有权限、刷新会话、家庭切换、迟到响应和失败恢复测试包含在 72 项内。

最终 APK：`apps/fridge-app/build/app/outputs/flutter-apk/app-release.apk`。使用 aapt 对编译产物核实 `application-label:'小易冰箱'`，包名仍为 `com.smartfridge.smart_fridge_app`。ASCII 构建文件与工作区交付副本 SHA256 均为：

`fb0495a4db65ccd789e9d12e055e2b72857b863af71581ea5bc61d6694be611d`

Android 早期失败保留在 android-build.log、android-ascii-build.log；最终结果以 [android-final-build.log](evidence/2026-10-31-warm-harvest/android-final-build.log) 为准。APK 构建成功不等于正式分发或真机验收。

## 本轮真实浏览器验收

真实链路：本机 Edge、Flutter release、Gateway 8080、Auth/Family 8081、Fridge 8082、Recipe 8083、MySQL/Redis；独立验收账号及家庭，不使用真实用户凭据。使用普通鼠标坐标和键盘操作 Flutter，不依赖辅助语义代理点击。

| 路径 | 观察结果与证据 |
| --- | --- |
| 桌面登录、读库存、三维就绪 | 登录后家庭/冰箱/食材 GET 200；模型 ready，初始 3 条食材；[桌面真实工作区](evidence/2026-10-31-warm-harvest/app-desktop-final.png) |
| 桌面新增 | 普通点击表单新增「暖橙桌面验收酸奶」，POST 201；库存和场景 3 → 4；弹层期间模型输入暂停，关闭恢复；[新增成功](evidence/2026-10-31-warm-harvest/app-desktop-add-success.png) |
| 手机新增与草稿 | 390 × 844 新增「手机暖橙验收酸奶」，POST 201，4 → 5；验证关闭草稿、继续编辑和保存；[草稿提示](evidence/2026-10-31-warm-harvest/app-mobile-draft-confirm.png)、[新增成功](evidence/2026-10-31-warm-harvest/app-mobile-add-success.png) |
| 主导航状态与场景 | home → recipes → home，原 iframe/frame 仍连接，额外场景 HTML 加载次数 0；隐藏 data-active=false，返回恢复 true；未观察到 JS pageerror |
| 空家庭与隔离 | 同一账号切至新建空家庭，场景库存 0，未残留旧食材；切回恢复 5。无冰箱 GET 404 是现有约定；[空工作区](evidence/2026-10-31-warm-harvest/app-mobile-empty-family.png) |
| 只读成员 | 第二账号通过邀请码加入为 VIEWER，直接 POST foods 返回 403；其登录界面显示只读者与禁用新增原因；[最终只读界面](evidence/2026-10-31-warm-harvest/app-mobile-viewer-final.png) |
| 运营端演示 | 登录及四页导航、菜谱/订单搜索各返回 1 行、菜谱查询保留、320/390/1024/1440 宽页面无整体横向溢出、减少动态效果共 13 个检查通过，无 pageerror；[结果 JSON](evidence/2026-10-31-warm-harvest/admin-browser-check.json) |

真实业务关键路径是在本轮迭代中验收；最终显式按钮字体修正后重跑了完整自动化/构建，并使用独立新浏览器上下文再次采集登录、桌面/手机首页、菜谱和后台截图，复查移动导航与隐藏场景。该最终截图采集使用清晰标记的本地演示会话，不冒充又执行了一遍所有真实写入。见 [最终采集检查](evidence/2026-10-31-warm-harvest/app-final-capture.json) 和 [观察记录](evidence/2026-10-31-warm-harvest/browser-observations.json)。

## 未完成验收与保留边界

- 未执行 Android 真机安装、软键盘/系统返回、实际 GPU 的帧率/功耗及长时间内存验证；本轮 WebGL 浏览器使用 SwiftShader，不能代表真机性能。
- 未执行本轮后端 Maven 全模块测试、完整 190 断言接口矩阵、压力测试、cloud/Nacos 故障注入或正式环境验收。
- 安卓仍是明示用途的厨房参考图和真实库存清单；实时 WebGL 运行于 Web。实际 3D 是几何模型，概念照片不能当作实时渲染成果。
- 推送、布局编辑、其他主题切换、做饭扣减、时间线/撤销、运营真实 API/交易/导出和正式 Android 签名仍未实现，不因本轮视觉完成而改变。
- 三版 90 张概念图保留选稿时名称和模拟数据，作为选稿历史；最终名称、实际能力和验收以本报告及当前实现为准。

后续阶段开始时继续遵守 AGENTS.md 的阶段审查要求；本次 UI 任务没有自动扩展为时间线后端开发。
