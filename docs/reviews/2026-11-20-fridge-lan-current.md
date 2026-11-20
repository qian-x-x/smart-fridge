# 冰箱新版局域网入口复核

2026-11-20 将已在本机验收的食材清单新版接入现有 [局域网地址](http://10.66.46.139:18110/?v=list-recipes)。局域网 18110 与本机 18134 使用同一份 Web release，通过各自同源的 `/api/` 访问 18133 网关，读写同一套独立 V6 预览库存。两个浏览器地址的登录会话独立保存，首次使用局域网地址时用现有账号登录。

## 切换与审查

- 复用 `scripts/preview-quiet-white.mjs`，仅替换原 18110 WLAN 监听的启动参数。新版服务器绑定当前 WLAN IPv4 `10.66.46.139`，认证、库存、网关和本机预览的 18131 至 18134 端口均绑定回环地址。
- 预检原进程监听地址、旧页面脚本哈希及备用目录。用临时回环入口读取新版构建并检测带局域网来源的鉴权请求后，切换原 WLAN 监听并停止临时入口。恢复时，原构建位于 `apps/fridge-app/build/lan-web`，原上游为 `http://127.0.0.1:8080`。
- 检查浏览器源地址及网关鉴权。带局域网 `Origin` 的未登录家庭请求返回 401，只读成员制作返回 403。写入验证在预览库的独立测试家庭执行，涵盖编辑权限、库存版本与流水。

## 本轮验证

| 检查 | 结果 |
| --- | --- |
| `Invoke-WebRequest`、`Get-FileHash`、`Get-NetTCPConnection` | 两入口的 HTML、Flutter 主程序、三维页面、CanvasKit WASM 和番茄贴纸与已验收构建逐字节一致。五种资源返回 `Cache-Control: no-store`，监听与网关通过复核。 [运行记录](evidence/2026-11-20-fridge-lan-current/runtime-validation.json) |
| `docker exec sf-web sh -c 'wget -T 8 -qO- http://10.66.46.139:18110/main.dart.js \| sha256sum'` | Docker 容器网络可通过 WLAN 地址读取新版，脚本哈希一致。 [容器记录](evidence/2026-11-20-fridge-lan-current/container-validation.json) |
| `node build/sticker-local-preview/verify-list-recipes-lan.mjs`，设置 `FRIDGE_LIST_RECIPES_URL=http://10.66.46.139:18110` | 实际 Edge release 的桌面和手机尺寸共 20 项通过。拦截外部引擎和字体域名时，可通过局域网地址同源登录、筛选库存、查看食材贴纸和关联菜谱。番茄滑蛋实际扣减四种原料各一份，只读制作被拒绝，两入口读取到一致的扣减后库存。 [浏览器结果](evidence/2026-11-20-fridge-lan-current/browser-validation.json) |
| 本机 Chrome | 局域网地址打开新版登录页。 |

本轮验证涵盖实际 Web、网关及独立 V6 数据库，实体手机从 Wi-Fi 访问尚待实测。Flutter 和后端全量自动化、Android 真机验收属于本轮未执行的检查。

局域网服务器从仓库根目录启动时使用以下配置。`PREVIEW_HOST` 对应电脑当前的 WLAN IPv4，18133 由本机新版预览提供。

```powershell
$env:PREVIEW_HOST = '10.66.46.139'
$env:PREVIEW_PORT = '18110'
$env:PREVIEW_BUILD_DIR = (Resolve-Path 'apps/fridge-app/build/sticker-web').Path
$env:PREVIEW_API = 'http://127.0.0.1:18133'
node scripts/preview-quiet-white.mjs
```
