# 食材贴纸与库存交互审查

## 阶段一 · 目录、分区与按份入库

以本轮起始工作区为基线审查了该阶段完整差异。范围包括真实冰箱首页、勾选清单、贴纸资产、库存编辑兼容、批量入库接口、Flyway V6、契约和回归用例。

- 151 张经典白边贴纸以透明 WebP 随应用交付。13 个菜谱补充原料中，7 个借用相应食材插图，6 个使用分类图标。
- 蔬果、饮品、奶制品、鸡蛋与布丁默认冷藏。速冻食品、雪糕、冰淇淋和冰块默认冷冻。调味品、干货、豆腐、豆浆、干茶和其余常温包装零食默认变温。肉类和海鲜默认短期变温，可逐项切换长期冷冻。
- 新库存按整份入库并保留贴纸标识，允许修改份量、分区和日期。旧库存保留原单位。默认日期按冰箱时区和入库日设置，短期肉类海鲜为 1 天，冷冻为 30 天，其余为 7 天。这些日期用于库存提醒，可以在库存中修改。
- 批量新增依赖服务端编辑权限与本冰箱分区。库存与 ADD 流水同事务写入，以冰箱、操作人与请求标识限制重放范围，异清单冲突。页面遇到响应不确定时保留当前清单和请求标识。关闭清单会结束本次编辑。
- 修正了 Material 卡片上的点击反馈与旧迁移测试误计新增迁移的问题。旧迁移用例明确只升级至 V5，V6 从新版库存 API 自动化测试覆盖。

| 新执行的验证 | 结果 |
| --- | --- |
| `flutter test --no-pub --reporter expanded test/fridge_home_test.dart test/food_edit_test.dart test/fridge_workspace_controller_test.dart` | 24 项通过 |
| `dart analyze lib test` | 无问题 |
| `mvn -o -pl fridge-service -am test` | fridge 48 项、common-core 1 项通过 |
| Python Pillow、PyYAML 本地核对 | 151 张透明图、164 个唯一库项、161 处 OpenAPI 引用有效 |
| `git diff --check` 及起始快照差异审查 | 通过，工作区既有换行符警告 |

阶段一代码审查及自动化验证通过。真实 MySQL、浏览器全链路与 Android 真机验收进入下一阶段记录。

## 阶段二 · 冰箱内交互与菜谱扣减

复核起始工作区到本轮结果的源代码与完整差异。复核包括 Flutter 冰箱、菜谱匹配、原有库存编辑入口、WebGL 通信、Android 参考图、做饭服务、接口契约、构建资源和回归用例。

- Web 贴纸锚定到打开的冷藏隔层和抽屉坐标。悬停或键盘聚焦时抬高并显示名称，点击或触屏轻触打开相关菜谱。打开半边冷藏门时使用该侧的隔层。分区内超出展示位的贴纸可以翻页。Android 参考图使用相同库存和点击入口。
- iframe 事件必须来自同源场景窗口，食材点击同时校验当前库存版本。页面进入弹层时暂停场景输入和浮动。切换冰箱后，入库与制作重新核对家庭、冰箱和编辑权限。
- 菜谱按明确食材名及别名匹配，显示缺少和可选原料。立即制作按菜谱的一道扣减，每种必需贴纸食材扣 1 份，优先使用点中的可用批次。历史计量库存可按相容单位和实际用量扣减。
- 做饭事务校验库存、版本和到期日期并记录流水。先保留制作请求标识，再检查待扣减库存，使并发重放可取回原记录。重放校验操作人及关键请求内容。客户端在弹层打开期间保留未知结果的请求标识和待扣清单。
- 首轮测试发现旧 API 也有按份记录，已将单份限制限定到贴纸库存，恢复旧接口的数量语义。真实 Web 构建还发现中文资源文件名经 URI 编码，已修正 iframe 贴纸路径并复验。隔离环境的测试家庭用现有分步创建接口初始化，实际家庭初始化的 Seata 流程另行验收。

### 代码审查及自动化验证

| 本轮命令或检查 | 结果 |
| --- | --- |
| `dart analyze lib test` | 无问题 |
| `flutter test --no-pub --reporter expanded` | 97 项通过，覆盖 18 道菜可按份匹配、缺料提示、固定扣减、失败重试和旧库存 |
| `node --test scripts/tests/fridge3d.test.mjs` | 9 项通过，覆盖各分区锚点、开合状态和俯视取景 |
| `mvn -o -pl fridge-service -am package` | fridge 50 项、common-core 1 项通过，含并发重放、外部库存、过期库存和整份扣减 |
| `flutter build web --release --no-pub --no-wasm-dry-run --output build/sticker-web` | 通过。验证产物同步了随后的静态贴纸地址修正，并核对源文件与构建文件的 SHA-256 |
| `flutter build apk --debug --no-pub` | 通过。APK 压缩包完整性、Android Debug 签名与 151 张贴纸逐文件核对通过。[APK 校验](evidence/2026-11-20-fridge-ingredient-stickers/android-build.json) |
| `git diff --check` 和起始工作区完整差异审查 | 通过 |

### 本机真实环境端到端验收

Edge 使用软件 WebGL 运行 Web release，登录、家庭访问、库存和扣减通过本机网关与隔离 MySQL 表完成。隔离冰箱库 Flyway V6 已生效。桌面 1440×1000 和手机 390×844 视口共 21 项通过，包含只读与跨家庭限制、三区的真实库存、贴纸悬停及名称、触屏点选、缺料状态、立即制作与幂等扣减。[浏览器结果](evidence/2026-11-20-fridge-ingredient-stickers/browser-validation.json)

151 张构建贴纸 URL 均返回 WebP。素材缩小到应用尺寸后保留主体像素和透明通道。完整 164 项目录在独立测试冰箱批量入库后逐项核对，重放后总数仍为 164。[资源及整批验证](evidence/2026-11-20-fridge-ingredient-stickers/catalog-validation.json)

[添加食材清单](evidence/2026-11-20-fridge-ingredient-stickers/ingredient-picker-desktop.png) · [冷藏贴纸悬停](evidence/2026-11-20-fridge-ingredient-stickers/ingredient-sticker-hover.png) · [手机视口相关菜谱](evidence/2026-11-20-fridge-ingredient-stickers/ingredient-recipes-mobile.png)

本轮验收范围为贴纸库存与制作路径。Android 真机、硬件 WebGL、Seata 事务及真实业务全矩阵待验。交付为本地工作区代码和构建。
