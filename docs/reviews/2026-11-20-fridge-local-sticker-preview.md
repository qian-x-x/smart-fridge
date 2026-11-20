# 本机冰箱贴纸预览

浏览器常用的 3030 与 18110 入口当时均提供旧 Web 构建。18110 返回的三维页面版本为 `fridge-drawer-frame-v2.1`，贴纸模块请求返回 404。主库存库的迁移版本为 V4，新批量入库接口所需的表在 V6 创建。

[本机新版预览](http://127.0.0.1:18134/?v=stickers-v22) 从 `apps/fridge-app/build/sticker-web` 提供新版 release。现有账号和库存从同一次 MySQL 快照复制到两份独立的预览库。预览使用独立数据库账号、Redis 库和签名密钥，库存副本迁移至 V6。原账号可在新地址重新登录，该地址中的库存和家庭操作写入预览副本。前端、网关和两个业务进程均只绑定回环地址。

## 本轮检查

- 使用 `Invoke-WebRequest` 和 Python HTTP 请求核对 3030、18110 与 18134 的网页、三维入口和贴纸模块。18134 返回的 Web 主程序与两个场景资源逐字节匹配新版构建。
- 使用本机 MySQL 查询核对源库和预览库的迁移版本。原账号哈希、食材名称和数量与副本逐条对齐。网关的菜谱路由接入现有只读菜谱服务。
- `node build/sticker-local-preview/verify.mjs` 在 Edge 实际运行 release，22 项通过。覆盖真实 Seata 家庭初始化、三区、多选和份量、悬停、触屏、缺料提示、库存流水及幂等扣减。[浏览器结果](evidence/2026-11-20-fridge-local-sticker-preview/browser-validation.json)
- `git diff --check` 通过。运行参数和日志位于 `build/sticker-local-preview`。[本机运行核对](evidence/2026-11-20-fridge-local-sticker-preview/runtime-check.json)

本轮属于本机运行和浏览器验收。Flutter 单元测试、Android 真机和局域网访问新版均未在本轮重新验收。
