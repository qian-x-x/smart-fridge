# 手机浏览器登录页空白修复审查

2026-11-20 复核 Flutter Web 的启动模板、渲染资源、字体清单及局域网预览产物。

## 发现与处理

- 旧版在模拟 Android 浏览器中能够返回 HTML 和“小易冰箱”标题。阻断 `www.gstatic.com` 的 CanvasKit WASM 请求后，页面没有首帧或登录路由，复现了空白现象。
- Flutter 启动改为从应用自身的 `canvaskit/` 路径读取引擎和 WASM。补齐本地 Roboto，消除首帧对外网备用字体下载的等待。字体取自当前 Flutter SDK 中的 `engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf`，源文件和构建内文件的 SHA-256 均为 `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`，随包附 Apache 2.0 许可。
- 首帧之前用 HTML 显示启动状态。引擎错误会显示重试按钮，等待超过 15 秒也能重试。首帧到达时移除启动提示并清除计时器。登录和家庭请求走原同源 `/api/` 网关，测试会话在验收后撤销。
- 旧预览的临时构建目录消失后，两处监听仍在但首页返回 404。最终 18110 的 WLAN 和回环监听使用项目构建目录 `apps/fridge-app/build/lan-web`。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `dart analyze lib test` 和认证会话、仓库、刷新相关的 `flutter test --no-pub --concurrency=1 --reporter expanded` | 静态分析无问题，6 项测试通过 |
| 在 `apps/fridge-app` 运行 `flutter build web --release --no-pub --no-wasm-dry-run --output build/lan-web`，以及 `node --check` 检查生成的引导脚本 | 通过。构建含 CanvasKit、本地 Roboto 和许可 |
| `node build/mobile-web-startup/verify.mjs <场景> <预览地址>` | Edge 6 个场景通过。拦截外网时，390 和 320 像素手机视口可见登录表单，320 像素同时验证禁用 WebGL。两种资源故障均显示反馈并可重新加载。1440 像素回环访问正常 |
| 390 像素视口内的真实账号登录 | 局域网地址的登录和家庭接口均返回 200，页面进入冰箱首页。测试会话退出返回 200，已撤销令牌再次请求家庭接口返回 401 |
| 局域网服务 | 宿主机与 Docker 容器通过 18110 的 WLAN 地址访问首页均返回 200，渲染资源由同一来源提供，无令牌访问家庭接口仍返回 401 |
| `git diff --check` | 通过 |

[手机尺寸的登录界面](evidence/2026-11-20-fridge-mobile-startup/mobile-login.png) · [故障重试](evidence/2026-11-20-fridge-mobile-startup/startup-retry.png) · [浏览器验证结果](evidence/2026-11-20-fridge-mobile-startup/browser-validation.json)

本轮通过手机视口、真实账号与后端的验证。Android 模拟器在内存分配报错后无法通过 `adb shell` 继续操作，未完成 Android 浏览器验证。用户原手机、完整业务矩阵及硬件 GPU 验收待执行。

从仓库根目录启动 WLAN 预览时，使用以下配置。

```powershell
$env:PREVIEW_HOST = '10.66.46.139'
$env:PREVIEW_PORT = '18110'
$env:PREVIEW_BUILD_DIR = (Resolve-Path 'apps/fridge-app/build/lan-web').Path
$env:PREVIEW_API = 'http://127.0.0.1:8080'
node scripts/preview-quiet-white.mjs
```
