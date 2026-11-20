# 本机 Web 预览登录故障复核

2026-11-19 复核 18110 预览的页面托管、同源 API 代理和认证会话。

## 发现与修复

- 18110 原由 `python -m http.server` 托管。页面返回 HTTP 200，`POST /api/v1/auth/login` 返回 HTML 501。检查时本机网关和认证服务的健康接口均返回 200。
- 18110 改用仓库的 `scripts/preview-quiet-white.mjs`，通过 `PREVIEW_BUILD_DIR` 加载当前 Flutter Web 构建，通过 `PREVIEW_API` 将 `/api/` 转发到本机 8080 网关。预览绑定 `127.0.0.1`，受保护的接口由网关鉴权。
- 在独立端口核对页面资源、API 状态码和未登录访问后切换 18110。首次浏览器验证完成登录和首页加载，检查脚本使用了移动端导航名。撤销该次验证会话，改用桌面导航名完成复测。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `node --check scripts/preview-quiet-white.mjs`、`git diff --check` | 通过 |
| 18110 页面、`main.dart.js` 与 Three.js 资源 | 页面及模块返回 200，主脚本与当前构建逐字节一致 |
| 无效登录与未授权访问 | 未知账号返回 HTTP 401 和 `UNAUTHORIZED`，无效请求体返回 HTTP 400 和 `VALIDATION_ERROR`。未登录访问家庭接口返回 401 |
| Edge 实际 Web release，使用用户提供的账号 | 登录返回 HTTP 200 和 `OK`，进入冰箱首页，家庭接口返回 200。界面退出请求返回 200 并回到登录页，测试令牌再次访问家庭接口返回 401 |

从仓库根目录启动该预览的命令如下。

```powershell
$env:PREVIEW_HOST = '127.0.0.1'
$env:PREVIEW_PORT = '18110'
$env:PREVIEW_BUILD_DIR = Join-Path $env:TEMP 'xiaoyi-fridge-frame-web'
$env:PREVIEW_API = 'http://127.0.0.1:8080'
node scripts/preview-quiet-white.mjs
```

本轮通过本机实际账号登录、读取家庭和退出验收。完整业务矩阵、Android 真机及硬件 GPU 验收待执行。
