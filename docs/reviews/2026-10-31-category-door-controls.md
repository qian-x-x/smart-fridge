# 食材分类选择与开合状态修复审查

日期：2026-10-31。范围为用户提出的两项修改：分类改为选择，门和抽屉按钮分别反映实际开启状态。结论：代码审查、自动化验证及下述本地浏览器验收通过。未进入时间线等其他业务阶段，未提交、推送或部署。

## 改动与审查

1. 新增食材的分类改为不可编辑的下拉选择，提供肉类、奶制品、蛋类、蔬菜、水果、海鲜、主食、豆制品、调味品、饮品、熟食、其他，共 12 项；默认「其他」。清单的分类筛选使用同一预设列表，并追加当前库存已有的旧分类，保留历史数据的可查询性，不改写既有记录。
2. 新增表单仅保存选中的分类字符串；提交期间按既有 canEdit / saving 状态禁用选择。只修改分类也会触发未保存内容保护。接口的 category 字段及服务端业务规则未改变。
3. 桌面筛选的有限表单字段改为一次布局的滚动列，结果列表保持独立滚动。重置先重置 FormField，再清空分类状态，避免旧选择被重置回调带回；已验证请求中 category 被移除。
4. 模型已有独立开合状态，本轮没有改动门/抽屉的状态机。底部四个部件按钮统一由实际 view 状态更新 aria-pressed，高亮与提示同步；多个开启可以同时高亮。「展开概览」与「全部关闭」保留为命令按钮，移除概览永久高亮。概览中的半开抽屉也视为开启。
5. 初始加载、结构按钮、模型拾取、键盘以及 Flutter 分区同步均进入同一 updateStatus 路径。缓存修订统一更新为 `warm-harvest-v1.5.1`，避免新 HTML 与旧模块混用。
6. 已检查本次完整增量 diff、新分类列表及完整工作区 diff 的范围。backend/contracts/infra/admin-web 的既有差异片段前后完全一致；未修改权限、家庭隔离、异步请求控制器或接口契约。Android 副本的 94 项源码/资源/配置与当前应用一致。见 [源文件审计](evidence/2026-10-31-category-door-controls/source-audit.json)及[本轮增量 diff](evidence/2026-10-31-category-door-controls/implementation.diff)。

## 本轮自动化与构建

| 命令 | 结果 |
| --- | --- |
| `dart analyze lib test` | 无问题 |
| `flutter test --no-pub --reporter expanded` | 74 项通过 |
| `node --test scripts/tests/fridge3d.test.mjs` | 5 项通过 |
| `flutter build web --release --no-pub` | 成功 |
| `flutter build apk --release --no-pub`（ASCII 副本） | 成功，58.9 MB，模板 debug 签名 |
| `git diff --check` | 通过 |

命令目录分别为 apps/fridge-app 和仓库根。日志与退出码见 [自动检查摘要](evidence/2026-10-31-category-door-controls/automatic-checks.json)。Android 结果见 [构建日志](evidence/2026-10-31-category-door-controls/android-build.log)与[产物校验](evidence/2026-10-31-category-door-controls/android-artifact.json)。当前工作区 APK 已更新，安装名仍为小易冰箱。

回归新增分类选择与草稿保护、分类筛选请求及重置，扩展真实新增测试验证所选分类，新增门/抽屉独立状态测试。迟到查询回归进一步要求旧请求实际发出后再发新请求；滚动辅助方法要求按钮可命中，并避免对待响应查询的持续进度动画执行 pumpAndSettle。初次失败记录保留于 [日志](evidence/2026-10-31-category-door-controls/flutter-tests-initial-failure.log)，最终全量结果为 74 项通过。

## 本轮浏览器与真实接口验收

Edge / SwiftShader，运行最终 Flutter release Web；真实链路为本机 Gateway、认证家庭/冰箱服务及 MySQL。为本轮建立独立验收账号与家庭，报告不记录密码或令牌。

- 桌面 1000 × 600、手机场景 350 × 300 分别检查四个部件的全部 16 种组合，共 32 种：模型 data-open-parts、各按钮 aria-pressed 和实际背景色一致；另检查初始概览和全部关闭，共 36 项场景断言通过，无 pageerror。手机场景同时覆盖减少动态效果设置。[结果](evidence/2026-10-31-category-door-controls/scene-controls-browser.json)。
- 390 × 844 手机用户端使用普通坐标点击、键盘输入和选择，从登录进入新增表单，选择「奶制品」后保存「分类验收牛奶」：POST /foods 返回 201，提交体 category 为奶制品；随后 GET 确认名称与分类持久化，两项真实链路检查通过，无 pageerror。[结果](evidence/2026-10-31-category-door-controls/category-browser-check.json)。
- 场景检查与分类检查针对同一最终构建分次执行。首次组合脚本在 Flutter 启动等待处超时，后续又校正了新增按钮的坐标；这些属于验收脚本定位/等待问题，未因此改动应用或略过断言。首次场景通过及后续启动超时的原始记录保留在 [组合脚本首次结果](evidence/2026-10-31-category-door-controls/browser-check-initial-failure.json)，场景范围单独摘录至上述结果；最终分类检查重新执行并通过。

实际截图：[分类选项](evidence/2026-10-31-category-door-controls/category-dropdown.png)、[已选择奶制品](evidence/2026-10-31-category-door-controls/category-selected.png)、[保存成功](evidence/2026-10-31-category-door-controls/category-save-success.png)、[左右门与变温同时开启](evidence/2026-10-31-category-door-controls/mobile-doors-and-variable-open.png)、[四个部件同时开启](evidence/2026-10-31-category-door-controls/mobile-all-open.png)。

## 尚未执行的验收

本轮没有执行 Android 真机/软键盘/实际 GPU 性能、完整后端 Maven/接口矩阵或运营端构建。前一轮这些项目的记录不能算作本轮重跑。测试 APK 构建和复制校验通过，不等于正式签名或真机端到端验收；服务端旧分类保持原值，不做数据迁移。
