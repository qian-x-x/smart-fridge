# 当前 Web 预览局域网访问复核

2026-11-19 将当前 Flutter Web 预览接入 WLAN。预览在 `10.66.46.139:18110` 监听，并通过同源 `/api/` 代理访问本机 8080 网关。18110 的 WLAN 和回环监听使用同一份构建。API 权限由网关和业务服务校验。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `Get-NetTCPConnection -LocalPort 18110 -State Listen` | WLAN `10.66.46.139:18110` 和回环 `127.0.0.1:18110` 均监听 |
| `docker exec sf-web wget -S -T 6 -O /dev/null http://10.66.46.139:18110/` | 容器网络经 WLAN 地址访问首页返回 HTTP 200 |
| 局域网地址请求页面与资源 | 首页、`main.dart.js`、CanvasKit WASM 和 Three.js 页面均返回 200。主脚本与当前构建逐字节一致 |
| 同源 API 鉴权探测 | 无令牌访问家庭接口返回 401。带局域网 `Origin` 的无效登录 POST 返回 401 和 `UNAUTHORIZED` |
| 本机 Edge 真实账号验收 | 从 WLAN 地址登录得到 200，进入冰箱首页并成功加载家庭。退出得到 200，已退出的令牌访问家庭接口返回 401 |

从仓库根目录重启 WLAN 预览时使用以下命令。电脑更换网络后，`PREVIEW_HOST` 使用新 WLAN IPv4 地址。

```powershell
$env:PREVIEW_HOST = '10.66.46.139'
$env:PREVIEW_PORT = '18110'
$env:PREVIEW_BUILD_DIR = Join-Path $env:TEMP 'xiaoyi-fridge-frame-web'
$env:PREVIEW_API = 'http://127.0.0.1:8080'
node scripts/preview-quiet-white.mjs
```

本轮验证覆盖局域网地址的托管、容器网络可达性和真实登录会话。同一 Wi-Fi 的独立手机或电脑实测、完整业务矩阵及 Android 真机验收待执行。
