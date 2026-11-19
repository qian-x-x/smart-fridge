# 家庭页面移除开源许可入口审查

日期：2026-11-10。

用户要求：删除家庭页面的开源许可说明和入口。

## 范围与完整差异

- 正式应用仅修改 [profile_page.dart](../../apps/fridge-app/lib/features/profile/presentation/profile_page.dart)：删除底部「开源许可」按钮及其 `showLicensePage` 回调，共 5 行；该说明页不再从家庭页面打开。
- 已审查完整页面、此次 [增量 diff](evidence/2026-11-10-family-license-entry/incremental-source.diff) 及该文件相对提交基线的完整 diff；原有静白全景文案属于之前的改动，本轮保留。其他既有工作区差异未纳入本次改动。
- 同时检索正式应用功能页及离线演示，未发现其他同名入口；离线演示本身没有该入口，无需修改。
- 依赖许可文件、字体声明及启动时的许可证注册保持原样；本轮只调整家庭页面呈现。

## 正确性审查

删除的是独立按钮和导航回调，没有增加权限检查、网络请求、异步任务或状态。家庭创建、加入、成员管理、退出确认和其余设置逻辑均不变；未修改会话、家庭选择、持久化或后端接口，无新增权限、家庭数据隔离、异步竞态、失败恢复及兼容性问题。完整 diff 未发现需要修复的正确性缺陷。

## 本轮验证

命令在 `apps/fridge-app` 运行，日志位于 [本轮证据目录](evidence/2026-11-10-family-license-entry/)：

- `dart analyze lib test`：通过，无问题。
- `flutter test --no-pub test/family_page_test.dart --reporter expanded`：6/6 通过，覆盖设置说明、家庭显示、创建、加入、成员操作及表单失败保留。
- `git diff --check`：通过；`pubspec.lock` 无差异。
- `flutter build web --release --no-pub`：通过，编译 67.5 秒，当前本地预览已读取新构建。
- PowerShell here-string 经 `node --input-type=module` 执行一次性 Edge 原生 CDP 检查：7/7 通过。使用全新临时浏览器配置进入演示账号，点击家庭导航；在 1440×1000 与 390×844 分别滚动至设置底部，核对许可入口及说明消失、其余设置和页尾可见，并点击退出后选择「留下」。无浏览器运行异常。

实际页面截图：[桌面](evidence/2026-11-10-family-license-entry/family-desktop.png)、[手机](evidence/2026-11-10-family-license-entry/family-mobile.png)；[浏览器检查明细](evidence/2026-11-10-family-license-entry/browser-review.json)。已查看截图，设置卡片及页尾无遗留占位。本轮代码审查及上述自动化、实际 release 演示页面检查通过。

未执行本轮后端接口、真实账号及家庭数据端到端验收；未重建 Android APK，未执行 Android 真机验收。此前各阶段验证结果不作为本轮结果。未提交、推送或公开部署。
