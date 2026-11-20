# 冰箱清单食材详情与制作审查

2026-11-20

## 本轮变更

- 清单点选食材后直接打开该食材的相关菜谱。页首显示白边贴纸、当前份量和分区。「库存详情」可打开使用、移动、编辑及丢弃操作，详情页头也使用同一贴纸。旧库存别名可以匹配现有素材，缺图条目显示默认图标。
- 清单筛选移除了标签输入框、验证状态及相关提示。名称、分类、分区、到期状态、期限和排序继续组合查询，既有标签查询接口兼容。
- 菜谱展示其他原料的已备、缺少和可选状态。拥有编辑权限且必需原料齐备时，可点「立即制作」扣减库存。制作成功后刷新清单结果，返回时保留原筛选。

## 代码审查

- 按本轮起始工作区审查了四个界面文件和两个测试文件的完整差异。清单复用冰箱内贴纸已有的菜谱匹配和制作流程，以全冰箱库存计算需要扣减的食材，优先使用点中的可用批次。
- 清单查询结果可能先于全冰箱缓存看见新库存。打开缺失或更新版本的结果时，在同一家庭及冰箱范围内刷新全量库存，刷新期间暂停制作与库存详情入口。继续使用现有家庭、冰箱、权限、版本校验和幂等请求。详情按钮使用当前工作区的权限与分区。
- 自动化复核了关闭清单时的延迟查询取消、旧查询晚到、制作响应丢失后的同键重试、只读访问、库存详情贴纸及制作后返回。实际浏览器补验了另一会话新增原料后直接点开清单结果。

## 本轮验证

| 命令或检查 | 结果 |
| --- | --- |
| `dart analyze lib test` | 无问题 |
| `flutter test --no-pub --reporter expanded` | 105 项通过 |
| `node --test scripts/tests/fridge3d.test.mjs` | 11 项通过 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output build/sticker-list-recipes-web` | 通过 |
| `flutter build apk --debug --no-pub` | 通过，压缩结构及 151 张贴纸已核验。[构建记录](evidence/2026-11-20-fridge-list-recipes/android-build.json) |
| `git diff --check` 与本轮增量差异检查 | 通过 |

在本机网关与独立 V6 MySQL 副本上，用独立测试家庭验证实际 Web release。候选构建和切换后的 18134 入口各通过 18 项检查，覆盖 1440×1000 和 390×844 视口。番茄滑蛋缺盐时显示缺料。补齐原料后点一次「立即制作」，四种原料各扣一份并产生四条流水。手机尺寸下验证了只读查看，服务端制作请求返回 403。 [浏览器验证](evidence/2026-11-20-fridge-list-recipes/browser-validation.json) · [桌面菜谱](evidence/2026-11-20-fridge-list-recipes/list-recipes-desktop.png) · [库存详情](evidence/2026-11-20-fridge-list-recipes/list-stock-detail.png) · [手机菜谱](evidence/2026-11-20-fridge-list-recipes/list-recipes-mobile.png)

18134 已切换到验证后的构建，恢复用上一版文件留存。HTML、Flutter 入口、三维页面与西红柿贴纸的响应哈希与候选构建一致。 [本机预览](http://127.0.0.1:18134/?v=list-recipes) · [切换记录](evidence/2026-11-20-fridge-list-recipes/local-preview-validation.json)

本轮端到端验收范围为本机浏览器。Android 真机、硬件 WebGL、主运行环境与后端全量测试待执行。
